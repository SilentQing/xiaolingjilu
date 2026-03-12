import router from '@ohos.router';
import { RecordItemData, Category } from '../model/RecordItemData';

@Entry
@Component
struct RecordDetail {
  // 接收从列表页传过来的数据
  @State record: RecordItemData | null = null;

  // 控制全屏图片预览的状态
  @State isPreviewOpen: boolean = false;

  // 页面生命周期：获取路由参数
  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params.recordInfo) {
      this.record = params.recordInfo as RecordItemData;
    }
  }

  // 辅助方法：获取分类颜色
  private getCategoryColor(): string {
    if (!this.record) return '#000000';
    switch (this.record.category) {
      case Category.Bill: return '#FF5E5E';
      case Category.Schedule: return '#007DFF';
      case Category.Knowledge: return '#4CAF50';
      default: return '#666666';
    }
  }

  build() {
    // 使用 Stack 布局，方便把全屏图片盖在最上面
    Stack() {
      // --- 底层：常规详情页面 ---
      Column() {
        // 1. 自定义顶部导航栏
        Row() {
          Image($r('app.media.ic_back')) // 请准备一个返回箭头图标
            .width(24).height(24)
            .onClick(() => router.back())

          Text('记录详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 16 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)

        if (this.record) {
          // 2. 可滚动的内容区
          Scroll() {
            Column({ space: 16 }) {

              // 顶部：大图裁剪预览（点击可全屏）
              Image(this.record.imagePath)
                .width('100%')
                .height(200)
                .objectFit(ImageFit.Cover) // 缩放裁剪填满
                .borderRadius(12)
                .onClick(() => {
                  // 点击图片，打开全屏预览
                  this.isPreviewOpen = true;
                })

              // 标题与高光数据区
              Row() {
                Column() {
                  Row() {
                    Text(this.record.category === Category.Bill ? '账单' :
                      this.record.category === Category.Schedule ? '日程' : '知识')
                      .fontSize(12)
                      .fontColor(Color.White)
                      .backgroundColor(this.getCategoryColor())
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(4)
                      .margin({ right: 8 })

                    Text(this.record.title)
                      .fontSize(22)
                      .fontWeight(FontWeight.Bold)
                      .layoutWeight(1)
                  }.width('100%')

                  Text(`收录于 ${this.record.createTime}`)
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 8 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                // 核心提取数值（如金额）
                if (this.record.highlightValue) {
                  Text(this.record.highlightValue)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bolder)
                    .fontColor(this.getCategoryColor())
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)

              // 完整文本展示区
              Column() {
                Text('OCR 提取文本')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#666666')
                  .margin({ bottom: 12 })
                  .width('100%')

                Text(this.record.summary)
                  .fontSize(16)
                  .lineHeight(24)
                  .fontColor('#333333')
                  .width('100%')
                  // 【毕设高分技巧】：允许用户长按复制这段文字
                  .copyOption(CopyOptions.LocalDevice)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)

            }
            .padding(16)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F4F5') // 页面底层灰色

      // --- 顶层：全屏图片预览 (通过 zIndex 覆盖) ---
      if (this.isPreviewOpen && this.record) {
        Column() {
          Image(this.record.imagePath)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain) // 全屏模式下保持比例，不裁剪
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#FF000000') // 纯黑色背景
        .zIndex(999) // 确保在最顶层
        // 添加点击事件：点击任意位置退出全屏
        .onClick(() => {
          this.isPreviewOpen = false;
        })
        // 这里可以加上 transition 动画让弹出更平滑
        .transition({ type: TransitionType.Insert, opacity: 0 })
        .transition({ type: TransitionType.Delete, opacity: 0 })
      }
    }
    .width('100%')
    .height('100%')
  }
}