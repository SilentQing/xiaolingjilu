@Component
export struct StatCard {
  @Link count: number // 声明响应式变量
  title: string = ''
  bgColor: string = ''
  iconUrl: Resource = $r('app.media.startIcon')


  build() {
    Column() {
      Row() {
        Image(this.iconUrl).width(20).height(20).margin({ right: 8 })
        Text(this.title).fontSize(14).fontColor('#666666')
      }.width('100%').margin({ bottom: 12 })

      Row() {
        Text(`${this.count}`) // 直接绑定响应式变量
          .fontSize(32)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#182431')
        Text(' 项')
          .fontSize(12)
          .fontColor('#999999')
          .margin({ left: 4, bottom: 4 })
      }.width('100%').alignItems(VerticalAlign.Bottom)
    }
    .width('48%')
    .padding(16)
    .backgroundColor(this.bgColor)
    .borderRadius(16)
  }
}