import { RecordItem } from './RecordItem'
import { MOCK_RECORDS } from '../mock/MockData'
import { RecordItemData } from '../model/RecordItemData'

@Component
export struct RecordListView {
  build() {
    Column() {
      // 简单的标题栏
      Text('记录列表')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20, left: 16 })
        .width('100%')

      // 使用 List 组件渲染模拟数据
      List({ space: 0 }) {
        ForEach(MOCK_RECORDS, (item: RecordItemData) => {
          ListItem() {
            RecordItem({ item: item })
          }
          .padding({ left: 16, right: 16 })
        }, (item: RecordItemData) => item.id)
      }
      .width('100%')
      .layoutWeight(1) // 占满剩余高度
      .edgeEffect(EdgeEffect.Spring) // 列表回弹效果
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8') // 浅灰色背景更显卡片层次
  }
}