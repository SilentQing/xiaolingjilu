import { RecordItem } from './RecordItem'
import { RecordItemData } from '../model/RecordItemData'
import { RdbManager } from '../dao/RdbManager';
import { EmbeddingService } from '../service/EmbeddingService';
import { VectorUtils } from '../utils/VectorUtils';

interface ScoredRecord {
  record: RecordItemData
  score: number
}

@Component
export struct SearchView {
  @State searchKeyword: string = '';                        // 绑定的搜索关键词
  @State searchResults: RecordItemData[] = [];              // 存放从数据库查出的真实结果
  @State isAiSearching: boolean = false;                    // AI 检索的加载状态，用于 UI 动效反馈
  private searchTimeoutId: number = -1;                     // 防抖定时器 ID
  @Prop @Watch('onTriggerRefresh') refreshTrigger: number;  // 接收父组件传来的刷新信号，并使用 @Watch 监听它的变化

  // 当信号发生变化时，自动执行此回调
  onTriggerRefresh() {
    // this.performSearch(this.searchKeyword); // 重新向 SQLite 要最新的数据！
    this.performSemanticSearch(this.searchKeyword);
  }

  /**
   * 核心 RAG 语义搜索引擎
   */
  async performSemanticSearch(keyword: string) {
    if (!keyword.trim()) {
      this.searchResults = [];
      this.isAiSearching = false;
      return;
    }

    this.isAiSearching = true;

    try {
      // 将用户的搜索词扔给智谱大模型，提取为语义向量
      const queryVector = await EmbeddingService.getEmbedding(keyword.trim());

      // 如果由于断网等原因没拿到向量，执行【降级策略】：走传统的 LIKE 模糊查询
      if (!queryVector || queryVector.length === 0) {
        console.info('向量化失败，降级为传统关键字查询');
        this.searchResults = await RdbManager.getInstance().queryRecords(undefined, keyword.trim());
        this.isAiSearching = false;
        return;
      }

      // 从本地 SQLite 拉取全部已有记录（在移动端，几千条数据全部拉到内存也是毫秒级的）
      const allRecords = await RdbManager.getInstance().queryRecords();

      // 核心数学运算：计算搜索词与每一条记录的余弦相似度
      const scoredRecords: ScoredRecord[] = [];
      for (const record of allRecords) {
        let score = 0;
        // 确保这条记录存有向量数据
        if (record.embedding && record.embedding.length > 0) {
          score = VectorUtils.cosineSimilarity(queryVector, record.embedding);
        }
        // 使用显式类型化的对象字面量
        const scoredRecord: ScoredRecord = {
          record: record,
          score: score
        };
        scoredRecords.push(scoredRecord);
      }

      // const scoredRecords: ScoredRecord[] = allRecords.map(record => {
      //   let score = 0;
      //   // 确保这条记录存有向量数据
      //   if (record.embedding && record.embedding.length > 0) {
      //     score = VectorUtils.cosineSimilarity(queryVector, record.embedding);
      //   }
      //   // 返回包含相似度分数的临时对象
      //   return { record: record, score: score };
      // });

      // 结果过滤与排序
      const topResults = scoredRecords
      // 设定一个相似度阈值（通常智谱 embedding-2 相关的在 0.4 以上，可以根据实际测试微调）
        .filter(item => item.score > 0.4)
        // 按照相似度从高到低排序 (降序)
        .sort((a, b) => b.score - a.score)
        // 还原回我们需要的 RecordItemData 数组
        .map(item => item.record);

      this.searchResults = topResults;

    } catch (error) {
      console.error('语义搜索彻底失败，走兜底查询', error);
      this.searchResults = await RdbManager.getInstance().queryRecords(undefined, keyword.trim());
    } finally {
      // 关闭 Loading 状态
      this.isAiSearching = false;
    }
  }


  // 向数据库发起模糊查询
  async performSearch(keyword: string) {
    // 如果搜索词为空，直接清空结果并返回
    if (!keyword.trim()) {
      this.searchResults = [];
      return;
    }

    try {
      // 调用 RdbManager 查库
      // 第一个参数传 undefined 表示不限分类，第二个参数传关键词
      const results = await RdbManager.getInstance().queryRecords(undefined, keyword.trim());

      // 将真实数据塞给状态变量，UI 自动刷新
      this.searchResults = results;
    } catch (error) {
      console.error('搜索查询失败', error);
    }
  }

  build() {
    Column() {
      // 顶部搜索框
      Search({
        value: this.searchKeyword,
        placeholder: '试试搜"去哪儿玩"或"花销"...'
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
            // this.performSearch(value);
            this.performSemanticSearch(value);
          }, 400);
        })
        .onSubmit((value: string) => {
          // 用户点击软键盘上的“搜索/回车”键时，立刻查询
          clearTimeout(this.searchTimeoutId);
          // this.performSearch(value);
          this.performSemanticSearch(value);
        })

      // 搜索结果展示区
      Column() {
        if (this.isAiSearching) {
          Column() {
            LoadingProgress().width(48).height(48).color('#007DFF')
            Text('AI 语义网络检索中...').fontSize(14).fontColor('#007DFF').margin({ top: 12 })
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)

        } else if (this.searchKeyword.trim() === '') {
          // 状态 A：空白提示状态
          Column() {
            Image($r('app.media.search_placeholder'))
              .width(80).height(80).margin({ bottom: 16, top: 80 })
            Text('支持自然语言，搜你想搜的')
              .fontColor('#999999')
              .fontSize(14)
          }.width('100%').alignItems(HorizontalAlign.Center)

        } else if (this.searchResults.length === 0) {
          // 状态 B：无结果状态
          Text(`未在记忆库中找到与 "${this.searchKeyword}" 相关的语义记录`)
            .fontColor('#999999')
            .fontSize(14)
            .margin({ top: 80 })

        } else {
          // 状态 C：渲染高相似度 AI 检索结果
          List({ space: 0 }) {
            ForEach(this.searchResults, (item:RecordItemData) => {
              ListItem() {
                RecordItem({ item: item })
              }
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url: 'pages/RecordDetail',
                  params: { recordInfo: item }
                });
              })
            }, (item: RecordItemData) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
        }

        // if (this.searchKeyword.trim() === '') {
        //   // 空白状态：提示用户输入
        //   Column() {
        //     Image($r('app.media.search_placeholder')) // 搜索引导的占位图，放大镜
        //       .width(120).height(120).margin({ bottom: 16, top: 80 })
        //     Text('输入关键词查找记录')
        //       .fontColor('#999999')
        //       .fontSize(14)
        //   }.width('100%').alignItems(HorizontalAlign.Center)
        //
        // } else if (this.searchResults.length === 0) {
        //   // 无结果状态
        //   Text(`找不到与 "${this.searchKeyword}" 相关的记录`)
        //     .fontColor('#999999')
        //     .fontSize(14)
        //     .margin({ top: 80 })
        //
        // } else {
        //   // 渲染复用的列表卡片
        //   List({ space: 0 }) {
        //     ForEach(this.searchResults, (item: RecordItemData) => {
        //       ListItem() {
        //         RecordItem({ item: item })
        //       }
        //       .padding({ left: 16, right: 16 })
        //       .onClick(() => {
        //         // 点击搜索出来的卡片，同样跳转到详情页
        //         this.getUIContext().getRouter().pushUrl({
        //           url: 'pages/RecordDetail',
        //           params: { recordInfo: item }
        //         });
        //       })
        //     }, (item: RecordItemData) => item.id)
        //   }
        //   .width('100%')
        //   .layoutWeight(1)
        // }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
  }
}