import { RecordItem } from './RecordItem'
import { MOCK_RECORDS } from '../mock/MockData'
import { RecordItemData } from '../model/RecordItemData'
import { RdbManager } from '../dao/RdbManager';

@Component
export struct SearchView {
  @State searchKeyword: string = ''; // 绑定的搜索关键词
  // 存放从数据库查出的真实结果
  @State searchResults: RecordItemData[] = [];

  // 防抖定时器 ID（前端工程化高级技巧）
  private searchTimeoutId: number = -1;

  // 向数据库发起模糊查询
  async performSearch(keyword: string) {
    // 1. 如果搜索词为空，直接清空结果并返回
    if (!keyword.trim()) {
      this.searchResults = [];
      return;
    }

    try {
      // 2. 调用 RdbManager 查库
      // 第一个参数传 undefined 表示不限分类，第二个参数传关键词
      const results = await RdbManager.getInstance().queryRecords(undefined, keyword.trim());

      // 3. 将真实数据塞给状态变量，UI 自动刷新
      this.searchResults = results;
    } catch (error) {
      console.error('搜索查询失败', error);
    }
  }

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
      // 顶部搜索框
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

          // 避免用户每打一个字母就疯狂查一次数据库，延迟 300 毫秒后再查
          clearTimeout(this.searchTimeoutId);
          this.searchTimeoutId = setTimeout(() => {
            this.performSearch(value);
          }, 300);
        })
        .onSubmit((value: string) => {
          // 用户点击软键盘上的“搜索/回车”键时，立刻查询
          clearTimeout(this.searchTimeoutId);
          this.performSearch(value);
        })

      // 搜索结果展示区
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
              .onClick(() => {
                // 点击搜索出来的卡片，同样跳转到详情页
                this.getUIContext().getRouter().pushUrl({
                  url: 'pages/RecordDetail',
                  params: {
                    recordInfo: item
                  }
                });
              })
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