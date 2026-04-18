import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { FileManager } from "../utils/FileManager";
import { common } from "@kit.AbilityKit";
import { OcrService } from "../service/OcrService";
import { RdbManager } from "../dao/RdbManager";
import { Category, RecordItemData } from "../model/RecordItemData";
import { util } from "@kit.ArkTS";
import { display, PromptAction, window } from "@kit.ArkUI";
import { DeepSeekService } from "../service/DeepSeekService";
import { EmbeddingService } from "../service/EmbeddingService";
import { StatCard } from "./StatCard";
import { InformationExtractionService } from "../service/InformationExtractionService";

@Component
export struct UploadView {
  @State selectedImageUri: string = ''; // 存放选中的图片 URI
  @State isProcessing: boolean = false; // 内部状态：是否正在识别

  // 用于底部弹窗的状态变量
  @State isShowConfirmSheet: boolean = false; // 控制面板显示/隐藏
  @State pendingRecord: RecordItemData | null = null; // 暂存识别出的原始记录

  // 用于表单双向绑定的编辑状态
  @State editTitle: string = '';
  @State editSummary: string = '';
  @State editCategory: Category = Category.Knowledge;

  // 看板数据状态
  @State billCount: number = 0;
  @State scheduleCount: number = 0;
  @State knowledgeCount: number = 0;

  // 接收 Index.ets 传来的刷新信号
  @Prop @Watch('onTriggerRefresh') refreshTrigger: number = 0;

  @State displayHeight:number = 0;

  // 专门用于响应监听的回调函数
  onTriggerRefresh() {
    console.info('UploadView 收到刷新信号，重新加载看板数据');
    this.loadDashboardData();
  }

  // 获取当前组件的上下文
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  uiContext: UIContext = this.getUIContext();
  promptAction: PromptAction = this.uiContext.getPromptAction();

  aboutToAppear() {
    this.loadDashboardData();
    console.info('加载看板数据');

    let displayClass: display.Display | null = null;
    try {
      displayClass = display.getDefaultDisplaySync();
      this.displayHeight = displayClass.height;
    } catch (exception) {
      console.error(`Failed to get default display. Code: ${exception.code}, message: ${exception.message}`);
    }

  }

  // 加载看板统计数据
  async loadDashboardData() {
    try {
      // 获取所有数据进行内存统计（移动端几千条数据统计极快，暂不需要写复杂的 SQL GROUP BY）
      const allRecords = await RdbManager.getInstance().queryRecords();

      this.billCount = allRecords.filter(item => item.category === Category.Bill).length;
      this.scheduleCount = allRecords.filter(item => item.category === Category.Schedule).length;
      this.knowledgeCount = allRecords.filter(item => item.category === Category.Knowledge).length;

    } catch (error) {
      console.error('看板数据加载失败', error);
    }
  }

  @Builder
  ConfirmSheetBuilder() {
    Column() {
      // 弹窗标题
      Text('确认智能提取结果')
        .fontSize(20)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#212529')
        .margin({ top: 16, bottom: 16 })

      if (this.pendingRecord) {
        Scroll() {
          Column({ space: 16 }) {
            // 原图预览 (圆角沉浸式)
            Image(this.pendingRecord.imagePath)
              .width('100%')
              .height(200)
              .objectFit(ImageFit.Contain)
              .borderRadius(12)
              .backgroundColor('#E9ECEF')

            // 核心标签与高亮数值 (金额/日期)
            Row() {
              // 类别徽章 (动态变色)
              Text(this.pendingRecord.category === Category.Bill ? '💸 消费账单' : '📅 知识/日程')
                .fontColor(Color.White)
                .backgroundColor(this.pendingRecord.category === Category.Bill ? '#FA5252' : '#228BE6')
                .padding({ top: 6, bottom: 6, left: 12, right: 12 })
                .borderRadius(20)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)

              Blank() // 撑开空间

              // 高亮提取值 (例如：金额 ¥18.50)
              if (this.pendingRecord.highlightValue) {
                Text(this.pendingRecord.highlightValue)
                  .fontSize(28)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor('#E03131')
              }
            }
            .width('100%')
            .padding({ left: 4, right: 4 })

            // 标题编辑框
            Column({ space: 8 }) {
              Text('标题').fontSize(14).fontColor('#868E96').fontWeight(FontWeight.Medium)
              TextInput({ text: this.pendingRecord.title })
                .onChange((value) => { this.pendingRecord!.title = value; })
                .backgroundColor('#F1F3F5')
                .borderRadius(8)
            }.width('100%').alignItems(HorizontalAlign.Start)

            // 智能标签流式布局 (Flex)
            if (this.pendingRecord.tags && this.pendingRecord.tags.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.pendingRecord.tags, (tag: string) => {
                  Text(`# ${tag}`)
                    .fontSize(13)
                    .fontColor('#495057')
                    .backgroundColor('#E9ECEF')
                    .padding({ top: 6, bottom: 6, left: 10, right: 10 })
                    .borderRadius(16)
                    .margin({ right: 8, bottom: 8 })
                })
              }.width('100%')
            }

            // 摘要内容编辑框
            Column({ space: 8 }) {
              Text('内容摘要').fontSize(14).fontColor('#868E96').fontWeight(FontWeight.Medium)
              TextArea({ text: this.pendingRecord.summary })
                .onChange((value) => { this.pendingRecord!.summary = value; })
                .height(100)
                .backgroundColor('#F1F3F5')
                .borderRadius(8)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
          .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1) // 滚动区域占据剩余所有空间
        .scrollBar(BarState.Off)

        // 7. 底部操作按钮栏
        Row({ space: 16 }) {
          Button('放弃')
            .type(ButtonType.Normal)
            .borderRadius(12)
            .backgroundColor('#F8F9FA')
            .fontColor('#495057')
            .layoutWeight(1)
            .onClick(() => { this.isShowConfirmSheet = false; })

          Button('入库保存')
            .type(ButtonType.Normal)
            .borderRadius(12)
            .backgroundColor('#228BE6')
            .layoutWeight(1)
            .onClick(() => {
              this.saveRecord();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 24 })
        .backgroundColor(Color.White)
      }
    }
    .width('100%')
    .height('100%')
  }

  // 辅助构建器：用于渲染分类按钮
  @Builder
  CategoryButton(label: string, category: Category) {
    Text(label)
      .fontSize(14)
      .fontColor(this.editCategory === category ? Color.White : '#666666')
      .backgroundColor(this.editCategory === category ? '#007DFF' : '#F2F2F2')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(16)
      .onClick(() => { this.editCategory = category })
  }

  build() {
    Scroll() {
      Column() {
        // 顶部问候语
        Row() {
          Column() {
            Text('早上好，')
              .fontSize(16)
              .fontColor('#666666')
              .margin({ bottom: 4 })
            Text('你的数字大脑运行良好')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#182431')
          }.alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 20 })

        // 数据看板区
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          StatCard({
            title: '账单聚合',
            count: $billCount,
            bgColor: '#FFF0F0',
            iconUrl: $r('app.media.ic_bill')
          }) // 浅红背景
          StatCard({
            title: '待办日程',
            count: $scheduleCount,
            bgColor: '#F0F8FF',
            iconUrl: $r('app.media.ic_schedule')}
          ) // 浅蓝背景

          // 占据一整行的宽卡片
          Column() {
            Row() {
              Image($r('app.media.ic_knowledge')).width(20).height(20).margin({ right: 8 })
              Text('知识图谱').fontSize(14).fontColor('#666666')
            }.width('100%').margin({ bottom: 12 })
            Row() {
                Text(this.knowledgeCount.toString()).fontSize(32).fontWeight(FontWeight.Bolder).fontColor('#182431')
                Text(' 条沉淀').fontSize(12).fontColor('#999999').margin({ left: 4, bottom: 4 })
            }.width('100%').alignItems(VerticalAlign.Bottom)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F0FFF0') // 浅绿背景
          .borderRadius(16)
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        Blank() // 把按钮推到下方或居中

        // 核心操作区 (视觉重心)
        Column() {
          if (this.selectedImageUri === '') {
            Column() {
              Image($r('app.media.ic_camera_scan')) // 扫描图标
                .width(48)
                .height(48)
                .margin({ bottom: 16 })
              Text('点击上传截图')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#182431')
              Text('支持自动提取账单、日程与摘要')
                .fontSize(12)
                .fontColor('#999999')
                .margin({ top: 8 })
            }
            .width('100%')
            .height(200)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#FFFFFF')
            .borderRadius(24)
            // 鸿蒙原生的物理阴影，增加可点击的暗示
            .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.05)', offsetY: 10 })
            .onClick(() => { this.pickScreenshot(); })
          } else {
            Column() {
              // 鸿蒙的 Image 组件可以直接渲染 Picker 返回的 file:// URI
              Image(this.selectedImageUri)
                .width('85%')
                .height(300)
                .objectFit(ImageFit.Contain)
                .borderRadius(16)
                .margin({ bottom: 20 })

              if (this.isProcessing) {
                // 识别中的 Loading
                LoadingProgress().width(64).height(64).color('#007DFF')
                Text('端云协同解析中...').fontSize(16).fontColor('#007DFF').margin({ top: 16 })
                Text('正在提取关键信息与生成知识标签').fontSize(12).fontColor('#999999').margin({ top: 8 })
              } else {
                Row() {
                  Button('重新选择')
                    .backgroundColor('#E5E5E5')
                    .fontColor('#333333')
                    .onClick(() => this.pickScreenshot())
                }
              }
            }
          }
        }
        .width('100%')
        .padding(20)
        .margin({ top: 20 })

      }
      .width('100%')


    }
    .width('100%')
    .height('100%')
    // 核心挂载点：绑定底部面板
    .bindSheet($$this.isShowConfirmSheet, this.ConfirmSheetBuilder(), {
      height: this.displayHeight*0.7,  // 占据屏幕的70%高度
      dragBar:true,
      backgroundColor: Color.White,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
      showClose: false           // 隐藏系统自带的关闭按钮
    })
  }

  // 拉起系统相册选择截图
  async pickScreenshot() {
    try {

      let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();                    // 实例化照片选择器配置
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;          // 限制只能选图片
      photoSelectOptions.maxSelectNumber = 1;                                                 // MVP 阶段每次只处理一张截图
      let photoPicker = new photoAccessHelper.PhotoViewPicker();                              // 调用相册选择
      let photoSelectResult = await photoPicker.select(photoSelectOptions);                   // 拉起选择器并等待用户操作
      //  处理返回结果
      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        // 获取选中图片的系统 URI (格式类似 file://media/Photo/...)
        this.selectedImageUri = photoSelectResult.photoUris[0];
        hilog.info(0x0000, 'UploadView', `图片选择成功: ${this.selectedImageUri}`);
        await this.processImage(this.selectedImageUri);
      }
    } catch (err) {
      hilog.error(0x0000, 'UploadView', `图片选择失败: ${JSON.stringify(err)}`);
    }
  }

  async processImage(uri: string) {
    this.isProcessing = true; // 触发界面的“端云协同解析中...”动画

    try {
      // 将相册 URI 拷贝到应用沙箱 (FileManager 是你之前可能写好的工具类)
      const sandboxPath = await FileManager.copyImageToSandbox(this.context, this.selectedImageUri);  // 拷贝图片到沙箱
      // 调用鸿蒙系统级 OCR 提取文本 (纯本地极速提取)
      const rawText = await OcrService.extractText(sandboxPath);

      if (!rawText || rawText.trim() === '') {
        this.promptAction.openToast({ message: '未能在截图中识别到有效文字' });
        this.isProcessing = false;
        return;
      }

      // 将生肉文本扔给我们的端云协同中枢！
      // 它会在底层自动决定是用 MindSpore 秒切账单，还是用 DeepSeek 提炼知识
      const extractedResult = await InformationExtractionService.processOcrText(rawText, sandboxPath);

      // 解析成功，将底层返回的数据绑定到 UI 的编辑状态上
      this.pendingRecord = extractedResult;
      this.editTitle = extractedResult.title;
      this.editSummary = extractedResult.summary;
      this.editCategory = extractedResult.category;

      // 触发并拉起底部的半模态确认弹窗 (ConfirmSheet)
      this.isShowConfirmSheet = true;

    } catch (error) {
      console.error('全链路解析遭遇异常', error);
      this.promptAction.openToast({ message: '解析异常，请检查网络或日志' });
    } finally {
      // 无论成功失败，关闭 Loading 动画
      this.isProcessing = false;
    }
  }


  // OCR 处理逻辑
  async startOcr() {
    if (!this.selectedImageUri) return;
    this.isProcessing = true;

    try {
      const sandboxPath = await FileManager.copyImageToSandbox(this.context, this.selectedImageUri);  // 拷贝图片到沙箱
      const rawText = await OcrService.extractText(sandboxPath);                                      // 调用侧端NPL原生 API 提取纯文本
      // const newRecord = this.analyzeTextWithCustomRules(rawText, sandboxPath);                     // 基于自定义规则对文本进行分类和提取
      const  newRecord = await DeepSeekService.analyzeText(rawText, sandboxPath)                      // 使用云端大模型对文本进行分类

      // 将 AI 提取的结果同步给编辑状态
      this.pendingRecord = newRecord;
      hilog.info(0x000, 'newRecord', `${JSON.stringify(newRecord)}`)
      this.editTitle = newRecord.title;
      this.editSummary = newRecord.summary;
      this.editCategory = newRecord.category;

      // 把标题、摘要和分类拼起来去获取语义向量
      const textToEmbed = `[${newRecord.category}] ${newRecord.title}: ${newRecord.summary}`;
      const vector = await EmbeddingService.getEmbedding(textToEmbed);
      newRecord.embedding = vector

      // 关闭加载动画，拉起底部确认面板
      this.isProcessing = false;
      this.isShowConfirmSheet = true;

      this.selectedImageUri = '';
      // 这里可以加一个 Toast 提示 "提取成功"
    } catch (error) {
      this.isProcessing = false;
      this.promptAction.openToast({ message: '文字提取失败，请重试' });
    }
  }

  // 保存入库方法
  async saveRecord() {
    if (!this.pendingRecord) return;

    // 把用户修改后的最新值覆盖回去

    this.pendingRecord.title = this.editTitle;
    this.pendingRecord.summary = this.editSummary;
    this.pendingRecord.category = this.editCategory;

    try {
      // 存入 SQLite
      await RdbManager.getInstance().insertRecord(this.pendingRecord);                // 将结构化数据写入 SQLite 数据库

      // 关闭面板，清空当前页面状态
      this.isShowConfirmSheet = false;
      this.selectedImageUri = '';               // 清空界面，准备下一次识别
      this.pendingRecord = null;

      this.promptAction.showToast({ message: '保存成功！' });
    } catch (err) {
      this.promptAction.showToast({ message: '保存失败' });
    }
  }
}