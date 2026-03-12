import { RecordItem } from './RecordItem'
import { MOCK_RECORDS } from '../mock/MockData'
import { RecordItemData } from '../model/RecordItemData'
@Entry
@Component
export struct SearchView {
  @State searchKeyword: string = ''; // 绑定的搜索关键词

  // 动态计算过滤后的列表
  private getFilteredRecords(): RecordItemData[] {
    if (!this.searchKeyword.trim()) {
      return []; // 搜索框为空时，不展示内容（或者你可以改为展示历史搜索）
    }
    const lowerKeyword = this.searchKeyword.toLowerCase();
    return MOCK_RECORDS.filter(item =>
    item.title.toLowerCase().includes(lowerKeyword) ||
    item.summary.toLowerCase().includes(lowerKeyword)
    );
  }

  build() {
    Column() {
      // 1. 顶部搜索框
      Search({
        value: this.searchKeyword,
        placeholder: '搜索账单、日程或知识内容...'
      })
        .width('90%')
        .height(40)
        .backgroundColor('#FFFFFF')
        .margin({ top: 12, bottom: 12 })
        .onChange((value: string) => {
          // 用户输入时，实时更新状态变量
          this.searchKeyword = value;
        })

      // 2. 搜索结果展示区
      Column() {
        if (this.searchKeyword.trim() === '') {
          // 空白状态：提示用户输入
          Column() {
            Image($r('app.media.search_placeholder')) // 搜索引导的占位图
              .width(120).height(120).margin({ bottom: 16, top: 80 })
            Text('输入关键词查找记录')
              .fontColor('#999999')
              .fontSize(14)
          }.width('100%').alignItems(HorizontalAlign.Center)

        } else if (this.getFilteredRecords().length === 0) {
          // 无结果状态
          Text(`找不到与 "${this.searchKeyword}" 相关的记录`)
            .fontColor('#999999')
            .fontSize(14)
            .margin({ top: 80 })

        } else {
          // 渲染复用的列表卡片
          List({ space: 0 }) {
            ForEach(this.getFilteredRecords(), (item: RecordItemData) => {
              ListItem() {
                RecordItem({ item: item })
              }
              .padding({ left: 16, right: 16 })
            }, (item: RecordItemData) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
  }
}