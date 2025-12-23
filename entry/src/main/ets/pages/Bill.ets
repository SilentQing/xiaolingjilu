@Entry
@Component
export struct Bill {
  @State message: string = 'Hello World';

  build() {
   Column() {
     Row() {
       Text('2025年10月')
       Text('报表')
         .margin({left:10})
         .borderWidth(1)
         .borderRadius(10)
     }
     .justifyContent(FlexAlign.Center)
     .width('100%')
     Text("账单")
       .width('100%')
       .height('100%')
       .backgroundColor('rgb(112,112,112)')
       .fontSize(40)
       .fontColor(Color.Black)
       .textAlign(TextAlign.Center)
   }
   .width('100%')
   .height('100%')
  }
}