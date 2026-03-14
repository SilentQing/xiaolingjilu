import { ScreenshotItem } from '../model/types/ScreenshotItem';
import { common } from '@kit.AbilityKit';
import { UploadView } from '../view/UploadView';
import { RecordListView } from '../view/RecordListView';
import { SearchView } from '../view/SearchView';

const MAX_SELECT_NUM = 1; // Select the maximum number of media files.
const TAG = 'Index';
interface ScreenshotEntity {
  id: number;
  uri: string;
  thumbnail: string;
  importTime: number;
  status: string;
  fileName: string;
  category: string;
  createdTime: number;
}

@Entry
@Component
struct Index {
  @State uri: string = '';
  @State isLoading: boolean = true;
  @State ScreenshotItems: Array<ScreenshotItem> = []
  @State currentIndex: number = 0
  @State focusIndex: number = 0;
  @State selectTopIndex: number = 0;
  @State selectBottomIndex: number = 0;
  @State index: number = 0
  @State refreshTrigger: number = 0                             // 刷新信号灯


  async aboutToAppear(): Promise<void> {
  }

  // 页面每次展示到屏幕上时触发（包括从详情页 back 回来）
  onPageShow() {
    this.refreshTrigger++

  }


  // 自定义 Tab 标签样式
  @Builder TabBuilder(title: string, index: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      Image(this.currentIndex === index ? selectedImg : normalImg)
        .width(24)
        .height(24)
        .margin({ bottom: 4 })
      Text(title)
        .fontColor(this.currentIndex === index ? '#007DFF' : '#182431')
        .fontSize(10)
        .fontWeight(500)
    }.width('100%')
  }

  build() {
    Column() {
      // 顶部标题栏
      Text('智能记录')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() {
          UploadView({ refreshTrigger: this.refreshTrigger })
        }
        .tabBar(('识别'))

        TabContent() {
          RecordListView({ refreshTrigger: this.refreshTrigger })
        }
        .tabBar('记录')

        TabContent() {
          SearchView({ refreshTrigger: this.refreshTrigger })
        }
        .tabBar('搜索')
      }
      .height("90%")
      .vertical(false)
      .barHeight(56)
      .onChange((index: number) => {
        this.currentIndex = index
        this.selectBottomIndex = index;
        this.refreshTrigger++;
      })

    }
    .width('100%')
    .height('100%')
    .padding({left:16, right:16})
  }
}
