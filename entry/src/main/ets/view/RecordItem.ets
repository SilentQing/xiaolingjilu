import { RecordItemData, Category } from '../model/RecordItemData'
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct RecordItem {
  @Prop item: RecordItemData; // 接收外部传入的数据


  // 根据分类获取颜色
  private getCategoryColor(): string {
    switch (this.item.category) {
      case Category.Bill: return '#FF5E5E';      // 红色系（账单）
      case Category.Schedule: return '#007DFF';  // 蓝色系（日程）
      case Category.Knowledge: return '#4CAF50'; // 绿色系（知识）
    }
  }

  build() {
    Row() {
      // 左侧：图片缩略图
      Image(this.item.imagePath)
        .width(80)
        .height(80)
        .borderRadius(8)
        .margin({ right: 12 })
        .objectFit(ImageFit.Cover)
        .backgroundColor('#F2F2F2')
        .sharedTransition(`shared_img_${this.item.id}`, {
          duration: 350,                 // 动画时长：350毫秒是人眼感觉最舒适的速率
          curve: Curve.FastOutSlowIn,    // 动画曲线：快出慢入，模拟真实的物理减速感
          delay: 0
        })

      // 中间：文本内容区
      Column() {
        Row() {
          // 分类小标签
          Text(this.item.category === Category.Bill ? '账单' :
            this.item.category === Category.Schedule ? '日程' : '知识')
            .fontSize(10)
            .fontColor('#White')
            .backgroundColor(this.getCategoryColor())
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .margin({ right: 8 })

          Text(this.item.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ bottom: 4 })

        Text(this.item.summary)
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 8 })

        Text(this.item.createTime)
          .fontSize(12)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧：高光展示区 (根据分类动态显示)
      Column() {
        if (this.item.category === Category.Bill && this.item.highlightValue) {
          // 账单显示金额
          Text('¥')
            .fontSize(12)
            .fontColor(this.getCategoryColor())
          Text(this.item.highlightValue)
            .fontSize(18)
            .fontWeight(FontWeight.Bolder)
            .fontColor(this.getCategoryColor())

        } else if (this.item.category === Category.Schedule && this.item.highlightValue) {
          // 日程显示倒计时
          Image($r('app.media.ic_clock')) // 假设你有一个时钟图标
            .width(16).height(16).margin({ bottom: 2 })
          Text(this.item.highlightValue)
            .fontSize(12)
            .fontColor(this.getCategoryColor())
        }
      }
      .width(70)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 12 })
    .shadow({ radius: 10, color: '#10000000', offsetX: 0, offsetY: 4 })
  }
}