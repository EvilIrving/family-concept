import { defineComponent, ref } from 'vue'
import { ElButton, ElTag } from 'element-plus'
import AkTable, { type AkPagination, type AkTableColumn } from './ak-table'

interface DemoRow {
  id: string
  name: string
  status: string
  createdAt: string
}

const mockData: DemoRow[] = [
  {
    id: '1',
    name: '张三',
    status: 'done',
    createdAt: '2026-03-19 09:30:00',
  },
  {
    id: '2',
    name: '李四',
    status: 'pending',
    createdAt: '2026-03-19 10:15:00',
  },
]

const formatDate = (value: string) => value.replace(' ', '\n')

export default defineComponent({
  name: 'AkTableUsageDemo',
  setup() {
    const loading = ref(false)

    const pagination = ref<AkPagination>({
      page: 1,
      pageSize: 10,
      total: 2,
      pageSizes: [10, 20, 50, 100],
    })

    const columns: AkTableColumn<DemoRow>[] = [
      {
        key: 'name',
        title: '姓名',
        dataIndex: 'name',
        minWidth: 160,
        sortable: true,
        filter: {
          type: 'input',
          placeholder: '搜索姓名',
        },
      },
      {
        key: 'status',
        title: '状态',
        dataIndex: 'status',
        width: 140,
        filter: {
          type: 'multi-select',
          options: [
            { label: '已完成', value: 'done' },
            { label: '处理中', value: 'pending' },
          ],
        },
        cellRender: ({ value }) => {
          const colorMap: Record<string, { bg: string; text: string }> = {
            done: { bg: '#ecfdf3', text: '#027a48' },
            pending: { bg: '#fff7ed', text: '#b54708' },
          }

          const current = colorMap[String(value)] || { bg: '#f4f4f5', text: '#606266' }

          return (
            <ElTag
              style={{
                backgroundColor: current.bg,
                color: current.text,
                border: 'none',
              }}
            >
              {String(value)}
            </ElTag>
          )
        },
      },
      {
        key: 'createdAt',
        title: '创建时间',
        dataIndex: 'createdAt',
        minWidth: 180,
        sortable: true,
        cellRender: ({ value }) => (
          <span style={{ whiteSpace: 'pre-line' }}>{formatDate(String(value))}</span>
        ),
      },
      {
        key: 'action',
        title: '操作',
        width: 120,
        fixed: 'right',
        cellRender: ({ row }) => (
          <ElButton type="primary" link onClick={() => console.log('detail', row.id)}>
            查看
          </ElButton>
        ),
      },
    ]

    const handlePageChange = (value: AkPagination) => {
      pagination.value = value
      console.log('page-change', value)
    }

    const handleSortChange = (value: { prop: string; order: 'ascending' | 'descending' | null }) => {
      console.log('sort-change', value)
    }

    const handleFilterChange = (value: Record<string, unknown>) => {
      console.log('filter-change', value)
    }

    const handleSelectionChange = (rows: DemoRow[]) => {
      console.log('selection-change', rows)
    }

    return () => (
      <AkTable
        columns={columns}
        data={mockData}
        loading={loading.value}
        pagination={pagination.value}
        showSelection
        showIndex
        onPageChange={handlePageChange}
        onSortChange={handleSortChange}
        onFilterChange={handleFilterChange}
        onSelectionChange={handleSelectionChange}
      />
    )
  },
})
