import {
  computed,
  defineComponent,
  reactive,
  ref,
  watch,
  type ExtractPropTypes,
  type PropType,
  type VNodeChild,
} from 'vue'
import {
  ElButton,
  ElCheckbox,
  ElCheckboxGroup,
  ElDatePicker,
  ElIcon,
  ElInput,
  ElOption,
  ElPagination,
  ElPopover,
  ElSelect,
  ElTable,
  ElTableColumn,
} from 'element-plus'
import { Filter } from '@element-plus/icons-vue'

export type AkAlign = 'left' | 'center' | 'right'
export type AkSortOrder = 'ascending' | 'descending' | null

export interface AkFilterOption {
  label: string
  value: string | number | boolean
}

export interface AkColumnFilter {
  type: 'input' | 'single-select' | 'multi-select' | 'date-range'
  options?: AkFilterOption[]
  placeholder?: string
  width?: number
  props?: Record<string, unknown>
}

export interface AkPagination {
  page: number
  pageSize: number
  total: number
  pageSizes?: number[]
}

export interface AkHeaderRenderContext {
  column: AkTableColumn
  columnIndex: number
  sortState: {
    prop?: string
    order?: AkSortOrder
  }
  filters: Record<string, unknown>
}

export interface AkCellRenderContext<T = Record<string, unknown>> {
  row: T
  value: unknown
  rowIndex: number
  columnIndex: number
  column: AkTableColumn<T>
}

export interface AkTableColumn<T = Record<string, unknown>> {
  key: string
  title?: string
  dataIndex?: keyof T | string
  width?: string | number
  minWidth?: string | number
  fixed?: 'left' | 'right'
  align?: AkAlign
  hidden?: boolean
  ellipsis?: boolean
  sortable?: boolean
  filter?: AkColumnFilter
  headerRender?: (ctx: AkHeaderRenderContext) => VNodeChild
  cellRender?: (ctx: AkCellRenderContext<T>) => VNodeChild
  children?: AkTableColumn<T>[]
  columnProps?: Record<string, unknown>
}

const propsDef = {
  columns: {
    type: Array as PropType<AkTableColumn[]>,
    default: () => [],
  },
  data: {
    type: Array as PropType<Record<string, unknown>[]>,
    default: () => [],
  },
  loading: {
    type: Boolean,
    default: false,
  },
  rowKey: {
    type: [String, Function] as PropType<string | ((row: Record<string, unknown>) => string)>,
    default: 'id',
  },
  pagination: {
    type: Object as PropType<AkPagination | undefined>,
    default: undefined,
  },
  showPagination: {
    type: Boolean,
    default: true,
  },
  showSelection: {
    type: Boolean,
    default: false,
  },
  showIndex: {
    type: Boolean,
    default: false,
  },
  indexLabel: {
    type: String,
    default: '序号',
  },
  indexWidth: {
    type: [String, Number],
    default: 60,
  },
  tableProps: {
    type: Object as PropType<Record<string, unknown>>,
    default: () => ({}),
  },
}

type AkTableProps = ExtractPropTypes<typeof propsDef>

const defaultPagination = (): AkPagination => ({
  page: 1,
  pageSize: 10,
  total: 0,
  pageSizes: [10, 20, 50, 100],
})

const getColumnProp = (column: AkTableColumn) => String(column.dataIndex ?? column.key)

const isEmptyFilterValue = (value: unknown, type?: AkColumnFilter['type']) => {
  if (type === 'multi-select' || type === 'date-range') {
    return !Array.isArray(value) || value.length === 0
  }
  return value === undefined || value === null || value === ''
}

const AkTable = defineComponent({
  name: 'AkTable',
  props: propsDef,
  emits: {
    'page-change': (_value: AkPagination) => true,
    'sort-change': (_value: { prop: string; order: AkSortOrder }) => true,
    'filter-change': (_value: Record<string, unknown>) => true,
    'selection-change': (_rows: Record<string, unknown>[]) => true,
    'row-click': (_row: Record<string, unknown>) => true,
  },
  setup(props: AkTableProps, { emit, expose }) {
    const tableRef = ref<InstanceType<typeof ElTable>>()

    const sortState = reactive<{
      prop?: string
      order?: AkSortOrder
    }>({
      prop: undefined,
      order: null,
    })

    const filters = reactive<Record<string, unknown>>({})
    const filterVisibleMap = reactive<Record<string, boolean>>({})

    const innerPagination = reactive<AkPagination>(defaultPagination())

    watch(
      () => props.pagination,
      (value) => {
        const nextValue = value ?? defaultPagination()
        innerPagination.page = nextValue.page
        innerPagination.pageSize = nextValue.pageSize
        innerPagination.total = nextValue.total
        innerPagination.pageSizes = nextValue.pageSizes ?? [10, 20, 50, 100]
      },
      { immediate: true, deep: true },
    )

    watch(
      () => props.columns,
      (columns) => {
        const walk = (list: AkTableColumn[]) => {
          list.forEach((column) => {
            if (column.filter) {
              if (!(column.key in filters)) {
                if (column.filter.type === 'multi-select' || column.filter.type === 'date-range') {
                  filters[column.key] = []
                } else {
                  filters[column.key] = ''
                }
              }
              if (!(column.key in filterVisibleMap)) {
                filterVisibleMap[column.key] = false
              }
            }
            if (column.children?.length) {
              walk(column.children)
            }
          })
        }
        walk(columns)
      },
      { immediate: true, deep: true },
    )

    const visibleColumns = computed(() => props.columns.filter((column) => !column.hidden))

    const emitFilterChange = () => {
      emit('filter-change', { ...filters })
    }

    const setFilterValue = (column: AkTableColumn, value: unknown) => {
      filters[column.key] = value
      emitFilterChange()
    }

    const clearFilterValue = (column: AkTableColumn) => {
      const nextValue =
        column.filter?.type === 'multi-select' || column.filter?.type === 'date-range' ? [] : ''
      setFilterValue(column, nextValue)
    }

    const handleSortChange = ({ prop, order }: { prop: string; order: AkSortOrder }) => {
      sortState.prop = prop
      sortState.order = order
      emit('sort-change', {
        prop,
        order,
      })
    }

    const handleSelectionChange = (rows: Record<string, unknown>[]) => {
      emit('selection-change', rows)
    }

    const handleRowClick = (row: Record<string, unknown>) => {
      emit('row-click', row)
    }

    const handleCurrentChange = (page: number) => {
      innerPagination.page = page
      emit('page-change', { ...innerPagination, pageSizes: [...(innerPagination.pageSizes ?? [])] })
    }

    const handleSizeChange = (pageSize: number) => {
      innerPagination.page = 1
      innerPagination.pageSize = pageSize
      emit('page-change', { ...innerPagination, pageSizes: [...(innerPagination.pageSizes ?? [])] })
    }

    const indexMethod = (index: number) =>
      (innerPagination.page - 1) * innerPagination.pageSize + index + 1

    const renderFilterContent = (column: AkTableColumn) => {
      const filter = column.filter
      if (!filter) return null

      const currentValue = filters[column.key]
      const commonProps = filter.props ?? {}

      let field: VNodeChild = null

      if (filter.type === 'input') {
        field = (
          <ElInput
            modelValue={String(currentValue ?? '')}
            placeholder={filter.placeholder ?? '请输入'}
            clearable
            {...{
              'onUpdate:modelValue': (value: string) => setFilterValue(column, value),
            }}
          />
        )
      }

      if (filter.type === 'single-select') {
        field = (
          <ElSelect
            modelValue={currentValue}
            placeholder={filter.placeholder ?? '请选择'}
            clearable
            style={{ width: '100%' }}
            {...commonProps}
            {...{
              'onUpdate:modelValue': (value: unknown) => setFilterValue(column, value),
            }}
          >
            {(filter.options ?? []).map((option) => (
              <ElOption key={String(option.value)} label={option.label} value={option.value} />
            ))}
          </ElSelect>
        )
      }

      if (filter.type === 'multi-select') {
        field = (
          <ElCheckboxGroup
            modelValue={Array.isArray(currentValue) ? currentValue : []}
            {...{
              'onUpdate:modelValue': (value: unknown[]) => setFilterValue(column, value),
            }}
          >
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                gap: '8px',
                maxHeight: '240px',
                overflow: 'auto',
              }}
            >
              {(filter.options ?? []).map((option) => (
                <ElCheckbox key={String(option.value)} value={option.value}>
                  {option.label}
                </ElCheckbox>
              ))}
            </div>
          </ElCheckboxGroup>
        )
      }

      if (filter.type === 'date-range') {
        field = (
          <ElDatePicker
            modelValue={Array.isArray(currentValue) ? currentValue : []}
            type="daterange"
            range-separator="-"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            style={{ width: '100%' }}
            {...commonProps}
            {...{
              'onUpdate:modelValue': (value: unknown) => setFilterValue(column, value ?? []),
            }}
          />
        )
      }

      return (
        <div style={{ width: `${filter.width ?? 220}px` }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              marginBottom: '12px',
            }}
          >
            <span style={{ fontWeight: 600 }}>{column.title ?? column.key}</span>
            <ElButton text type="primary" onClick={() => clearFilterValue(column)}>
              清空
            </ElButton>
          </div>
          {field}
        </div>
      )
    }

    const renderDefaultHeader = (column: AkTableColumn, columnIndex: number) => {
      const active = !isEmptyFilterValue(filters[column.key], column.filter?.type)

      return (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            minWidth: '0',
          }}
        >
          <span
            style={{
              flex: 1,
              minWidth: 0,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
            title={column.title ?? column.key}
          >
            {column.title ?? column.key}
          </span>

          {column.filter ? (
            <ElPopover
              visible={filterVisibleMap[column.key]}
              placement="bottom-end"
              width={column.filter.width ?? 220}
              trigger="click"
              {...{
                'onUpdate:visible': (value: boolean) => {
                  filterVisibleMap[column.key] = value
                },
              }}
            >
              {{
                reference: () => (
                  <ElIcon
                    style={{
                      cursor: 'pointer',
                      color: active ? 'var(--el-color-primary)' : '#909399',
                      flexShrink: 0,
                    }}
                  >
                    <Filter />
                  </ElIcon>
                ),
                default: () => renderFilterContent(column),
              }}
            </ElPopover>
          ) : null}
        </div>
      )
    }

    const renderColumn = (column: AkTableColumn, columnIndex: number): VNodeChild => {
      const hasChildren = !!column.children?.length
      const prop = getColumnProp(column)

      return (
        <ElTableColumn
          key={column.key}
          prop={hasChildren ? undefined : prop}
          label={column.title}
          width={column.width}
          minWidth={column.minWidth}
          fixed={column.fixed}
          align={column.align ?? 'left'}
          sortable={column.sortable ? 'custom' : false}
          showOverflowTooltip={column.ellipsis}
          {...(column.columnProps ?? {})}
        >
          {{
            header: () =>
              column.headerRender
                ? column.headerRender({
                    column,
                    columnIndex,
                    sortState: {
                      prop: sortState.prop,
                      order: sortState.order,
                    },
                    filters,
                  })
                : renderDefaultHeader(column, columnIndex),
            default: hasChildren
              ? undefined
              : ({ row, $index }: { row: Record<string, unknown>; $index: number }) => {
                  const value = row[prop]

                  if (column.cellRender) {
                    return column.cellRender({
                      row,
                      value,
                      rowIndex: $index,
                      columnIndex,
                      column,
                    })
                  }

                  return <span>{value as VNodeChild}</span>
                },
          }}
          {hasChildren ? column.children!.filter((item) => !item.hidden).map(renderColumn) : null}
        </ElTableColumn>
      )
    }

    const clearFilters = () => {
      const walk = (columns: AkTableColumn[]) => {
        columns.forEach((column) => {
          if (column.filter) {
            clearFilterValue(column)
          }
          if (column.children?.length) {
            walk(column.children)
          }
        })
      }
      walk(props.columns)
    }

    const clearSelection = () => {
      tableRef.value?.clearSelection?.()
    }

    expose({
      clearFilters,
      clearSelection,
      getFilters: () => ({ ...filters }),
    })

    return () => (
      <div class="ak-table" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        <ElTable
          ref={tableRef}
          data={props.data}
          loading={props.loading}
          rowKey={props.rowKey}
          {...props.tableProps}
          onSortChange={handleSortChange}
          onSelectionChange={handleSelectionChange}
          onRowClick={handleRowClick}
        >
          {props.showSelection ? (
            <ElTableColumn type="selection" width="55" align="center" />
          ) : null}

          {props.showIndex ? (
            <ElTableColumn
              type="index"
              label={props.indexLabel}
              width={props.indexWidth}
              align="center"
              index={indexMethod}
            />
          ) : null}

          {visibleColumns.value.map(renderColumn)}
        </ElTable>

        {props.showPagination && props.pagination ? (
          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <ElPagination
              currentPage={innerPagination.page}
              pageSize={innerPagination.pageSize}
              pageSizes={innerPagination.pageSizes}
              total={innerPagination.total}
              layout="total, sizes, prev, pager, next, jumper"
              onCurrentChange={handleCurrentChange}
              onSizeChange={handleSizeChange}
            />
          </div>
        ) : null}
      </div>
    )
  },
})

export default AkTable
