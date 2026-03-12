// entry/src/main/ets/mock/MockData.ets
import { RecordItemData, Category } from '../model/RecordItemData'

export const MOCK_RECORDS: RecordItemData[] = [
  {
    id: '1',
    imagePath: '', // 预览时可以先留空，或放一张本地 resources 里的图
    title: '瑞幸咖啡订单',
    summary: '瑞幸咖啡 (Luckin Coffee) 门店：中关村店。消费项目：生椰拿铁 1 杯。',
    category: Category.Bill,
    tags: ["工作","报销"],
    highlightValue: '18.50', // 账单金额
    createTime: '2026-03-11 09:30'
  },
  {
    id: '2',
    imagePath: '',
    title: '毕业设计中期答辩',
    summary: '地点：综合楼 302 会议室。准备材料：PPT、开题报告、系统演示 Demo。',
    category: Category.Schedule,
    tags: [],
    highlightValue: '2天后', // 日程倒计时
    createTime: '2026-03-10 14:00'
  },
  {
    id: '3',
    imagePath: '',
    title: '鸿蒙 ArkUI 状态管理',
    summary: '装饰器说明：@State 负责组件内状态，@Prop 负责父子单向同步，@Link 负责父子双向同步。',
    category: Category.Knowledge,
    tags: [],
    createTime: '2026-03-12 10:15'
    // 知识类不传 highlightValue，则不显示高光区
  },
  {
    id: '4',
    imagePath: '',
    title: '京东购物结算截图',
    summary: '实付金额：¥299.00。包含商品：机械键盘、数据线。',
    category: Category.Bill,
    tags: [],
    highlightValue: '299.00',
    createTime: '2026-03-12 11:20'
  },
  {
    id: '5',
    imagePath: '', // 预览时可以先留空，或放一张本地 resources 里的图
    title: '瑞幸咖啡订单',
    summary: '瑞幸咖啡 (Luckin Coffee) 门店：中关村店。消费项目：生椰拿铁 1 杯。',
    category: Category.Bill,
    tags: [],
    highlightValue: '18.50', // 账单金额
    createTime: '2026-03-11 09:30'
  },
  {
    id: '6',
    imagePath: '',
    title: '毕业设计中期答辩',
    summary: '地点：综合楼 302 会议室。准备材料：PPT、开题报告、系统演示 Demo。',
    category: Category.Schedule,
    tags: [],
    highlightValue: '2天后', // 日程倒计时
    createTime: '2026-03-10 14:00'
  },
  {
    id: '7',
    imagePath: '',
    title: '鸿蒙 ArkUI 状态管理',
    summary: '装饰器说明：@State 负责组件内状态，@Prop 负责父子单向同步，@Link 负责父子双向同步。',
    category: Category.Knowledge,
    tags: [],
    createTime: '2026-03-12 10:15'
    // 知识类不传 highlightValue，则不显示高光区
  },
  {
    id: '8',
    imagePath: '',
    title: '京东购物结算截图',
    summary: '实付金额：¥299.00。包含商品：机械键盘、数据线。',
    category: Category.Bill,
    tags: [],
    highlightValue: '299.00',
    createTime: '2026-03-12 11:20'
  }

]