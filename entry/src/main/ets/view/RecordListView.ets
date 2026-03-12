import { RecordItem } from './RecordItem'
import { MOCK_RECORDS } from '../mock/MockData'
import { Category, RecordItemData } from '../model/RecordItemData'
import { RdbManager } from '../dao/RdbManager';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface top_label {
  label: string;
  value: string;
}

@Component
export struct RecordListView {
  // 定义状态变量：存放从数据库查出来的真实数据
  @State records: RecordItemData[] = []

  // 当前选中的分类，默认查全部
  @State currentCategory: string = 'All'

  // 定义分类配置项，方便渲染顶部切换栏
  private categories: Array<top_label> = [
    { label: '全部', value: 'All' },
    { label: '账单', value: Category.Bill },
    { label: '日程', value: Category.Schedule },
    { label: '知识', value: Category.Knowledge }
  ]

  // 组件即将出现时调用
  aboutToAppear() {
    this.loadData()
  }

  // 向数据库要数据
  async loadData() {
    // 如果选了'All'，就传 undefined 去查全部；否则传对应的分类枚举
    const queryCategory = this.currentCategory === 'All' ? undefined : this.currentCategory
    // 调用我们刚在 RdbManager 写好的查询方法
    const result = await RdbManager.getInstance().queryRecords(queryCategory)
    // 把查到的数据塞给状态变量，UI 瞬间自动刷新！
    this.records = result
  }

  build() {
    Column() {
      // 顶部：分类切换栏 (Segment 风格)
      Row() {
        ForEach(this.categories, (cat: top_label) => {
          Text(cat.label)
            .fontSize(14)
            .fontWeight(this.currentCategory === cat.value ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentCategory === cat.value ? '#FFFFFF' : '#666666')
            .backgroundColor(this.currentCategory === cat.value ? '#007DFF' : '#E5E5E5')
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .borderRadius(16)
            .margin({ right: 8 })
            .onClick(() => {
              // 点击不同分类时：更新状态 -> 重新查库
              this.currentCategory = cat.value
              this.loadData()
            })
        }, (cat: top_label) => cat.value)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      // 下方：列表展示区
      if (this.records.length === 0) {
        // 数据库没查到数据时的空状态
        Column() {
          Text('暂无记录，快去上传截图吧')
            .fontColor('#999999')
            .fontSize(14)
            .margin({ top: 100 })
        }.layoutWeight(1).width('100%').alignItems(HorizontalAlign.Center)
      } else {
        // 渲染真实数据的列表
        List({ space: 0 }) {
          ForEach(this.records, (item: RecordItemData) => {
            ListItem() {
              RecordItem({ item: item })
            }
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              // 点击卡片，跳转到详情页，并把当前卡片的数据当做参数传过去
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/RecordDetail',
                params: {
                  recordInfo: item // 对应详情页 params.recordInfo
                }
              }, router.RouterMode.Standard, (err) => {
                if(err) {
                  hilog.error(0x0000, 'RecordListView',`Invoke pushUrl failed, code is ${err.code}, message is ${err.message}`);
                  return;
                }
                hilog.info(0x0000, 'RecordListView','Invoke pushUrl succeeded.');
              });
            });
          }, (item: RecordItemData) => item.id) // 用真实 ID 做为 Key 提升渲染性能
        }
        .width('100%')
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8') // 浅灰色背景更显卡片层次
  }
}