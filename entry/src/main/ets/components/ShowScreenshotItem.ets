import { ScreenshotItem } from "../model/types/ScreenshotItem"

@Component
export struct ShowScreenshotItem {
  @Prop item: ScreenshotItem

  build() {
    Row() {
      // 左侧缩略图
      Image(this.item.thumbnail)
        .width(60)
        .height(60)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)

      // 中部信息
      Column() {
        Text((this.item.importTime).toString())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#000000')

        Text(this.item.status)
          .fontSize(12)
          .fontColor('#666666')

        Text(this.item.fileName)
          .fontSize(12)
          .fontColor('#999999')
      }
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }
}