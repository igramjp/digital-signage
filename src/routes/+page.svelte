<script lang="ts">
  import "../app.css";
  import { SIGNAGE_VERSION } from "$lib";
  import {
    imageFiles as manifestImages,
    videoFiles as manifestVideos,
  } from "$lib/preload-manifest";
  import D3ChartStep2 from "$lib/D3ChartStep2.svelte";
  import D3ChartStep3 from "$lib/D3ChartStep3.svelte";
  import { onMount } from "svelte";
  import { base } from "$app/paths";

  // ベースパス付きアセット解決ヘルパー
  const asset = (p: string) => `${base}${p}`;
  // Tauri実行判定（リアクティブ変数として初期化、onMountで確実に判定）
  let isTauri = false;
  // 動画用ベース
  // Tauri 時はローカルHTTPサーバーのデフォルトポートを先に使い、
  // 後で invoke 取得で上書き（初期の読み込みを速くする）
  let videoBase: string = base;

  let videoElements: HTMLVideoElement[] = [];
  let isPlaying = false;
  let playCount = 0;
  let currentStep = 1; // 現在のステップ
  let currentTime = 0; // 現在の再生時間（秒）
  let duration = 0; // 動画の総時間（秒）
  let showDataPanel = false; // データパネルの表示/非表示
  let d3ChartStep2Component: D3ChartStep2; // D3ChartStep2コンポーネントの参照
  let d3ChartStep3Component: D3ChartStep3; // D3ChartStep3コンポーネントの参照
  let isInitialized = false; // 初期化完了フラグ
  let showImages = false; // 画像表示フラグ
  let showVideo = false; // 動画表示フラグ
  let currentVideo = ""; // 現在表示中の動画ファイル名
  let videoViewerElement: HTMLVideoElement; // 動画ビューアーの要素参照
  let preloadComplete = false; // プリロード完了フラグ
  let preloadProgress = 0; // プリロード進捗（0-100）
  let preloadStatus = "準備中..."; // プリロードステータス
  let step2ChartStarted = false; // Step2のチャートアニメーションが開始されたかどうか
  let step3ChartStarted = false; // Step3のチャートアニメーションが開始されたかどうか
  let step1Note1Active = false; // Step1のnote-area-item1がアクティブかどうか
  let step2Note2Active = false; // Step2のnote-area-item2がアクティブかどうか
  let step3Note3Active = false; // Step3のnote-area-item3がアクティブかどうか
  let step4Note4Active = false; // Step4のnote-area-item4がアクティブかどうか
  let isContinuousMode = false; // 連続再生モードかどうか

  // 各material-areaの動画インデックス管理
  let materialVideoIndex: { [key: number]: number } = {
    1: 0, // material1は画像のみ
    2: 0, // material2-1.mp4, material2-2.mp4
    3: 0, // material3-1.mp4, material3-2.mp4
    4: 0, // material4-1.mp4
    5: 0, // material5-1.mp4, material5-2.mp4, material5-3.mp4
  };

  // material-area内の動画要素への参照
  let material2Video1: HTMLVideoElement;
  let material2Video2: HTMLVideoElement;
  let material3Video1: HTMLVideoElement;
  let material3Video2: HTMLVideoElement;
  let material4Video1: HTMLVideoElement;
  let material5Video1: HTMLVideoElement;
  let material5Video2: HTMLVideoElement;
  let material5Video3: HTMLVideoElement;

  // 各ステップの動画ファイル配列
  const materialVideos: { [key: number]: string[] } = {
    1: [], // 画像のみ
    2: ["/videos/material2-1.mp4", "/videos/material2-2.mp4"],
    3: ["/videos/material3-1.mp4", "/videos/material3-2.mp4"],
    4: ["/videos/material4-1.mp4"],
    5: [
      "/videos/material5-1.mp4",
      "/videos/material5-2.mp4",
      "/videos/material5-3.mp4",
    ],
  };

  // 各ステップの動画ファイルのタイトル
  const materialVideoTitles: { [key: number]: string[] } = {
    1: [], // 画像のみ
    2: [
      "「亜硝酸リチウム水溶液の注入状況」",
      "「再不動態化のモニタリング状況」",
    ],
    3: ["「エアリフトの実施状況」", "「エアリフトの模擬状況」"],
    4: ["「水溶液除去の状況」"],
    5: [
      "「グラウト再注入の状況」",
      "「グラウトの充填状況」",
      "「グラウト充填確認の状況」",
    ],
  };

  // 再生開始のトリガー
  function handlePlay(event: Event): void {
    const video = event.target as HTMLVideoElement;
    // console.log("動画再生開始:", event);
    isPlaying = true;
    playCount++;
    // 動画要素から時間情報を取得
    if (video) {
      currentTime = video.currentTime;
      duration = video.duration || 0;
    }
    // ここに再生開始時の処理を書く
  }

  // material動画を連続再生する関数
  async function playAllMaterialVideos(step: number): Promise<void> {
    const videos = materialVideos[step];
    if (videos.length === 0) return; // material動画がない場合は何もしない

    // material動画インデックスを0にリセット
    materialVideoIndex = { ...materialVideoIndex, [step]: 0 };

    // 全てのmaterial動画を順番に再生
    for (let i = 0; i < videos.length; i++) {
      const videoElement = getMaterialVideoElement(step, i);
      if (!videoElement) continue;

      // インデックスを更新（動画を表示）
      materialVideoIndex = { ...materialVideoIndex, [step]: i };

      // 動画を最初から再生
      videoElement.currentTime = 0;
      await videoElement.play().catch(() => {
        // 自動再生が失敗した場合は無視
      });

      // 動画が終了するまで待機
      await new Promise<void>((resolve) => {
        const onEnded = () => {
          videoElement.removeEventListener("ended", onEnded);
          resolve();
        };
        videoElement.addEventListener("ended", onEnded);
      });

      // 動画が終了した画面のまま3秒待機（次の動画に切り替える前に待機）
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }

  // 再生終了のトリガー
  async function handleEnded(event: Event): Promise<void> {
    const video = event.target as HTMLVideoElement;
    // console.log("動画再生終了:", event);
    // console.log("終了したステップ:", currentStep);
    isPlaying = false;

    // 動画要素から時間情報を取得
    if (video) {
      currentTime = video.currentTime;
      duration = video.duration || 0;
    }

    // 連続再生モードの場合、次のステップに自動的に進む
    if (isContinuousMode) {
      // 3秒待機
      await new Promise((resolve) => setTimeout(resolve, 3000));

      // material動画があるSTEPの場合は、material動画も連続再生
      const hasMaterialVideos = materialVideos[currentStep].length > 0;
      if (hasMaterialVideos) {
        await playAllMaterialVideos(currentStep);
      }

      // 次のステップに進む
      if (currentStep < 5) {
        await switchVideo(currentStep + 1, true);
      } else {
        // Step5が終了したらSTEP1に戻る
        await switchVideo(1, true);
      }
    }
  }

  // 一時停止のトリガー
  function handlePause(event: Event): void {
    const video = event.target as HTMLVideoElement;
    // console.log("動画一時停止:", event);
    isPlaying = false;

    // 動画要素から時間情報を取得
    if (video) {
      currentTime = video.currentTime;
      duration = video.duration || 0;
    }
  }

  // 時間更新のトリガー
  function handleTimeUpdate(event: Event): void {
    const video = event.target as HTMLVideoElement;
    if (video) {
      currentTime = video.currentTime;
      duration = video.duration || 0;

      // Step1の動画が21秒に達したらnote-area-item1をアクティブに
      if (currentStep === 1 && currentTime >= 21 && !step1Note1Active) {
        step1Note1Active = true;
      }

      // Step1の動画が0秒付近に戻ったらnote-area-item1を非アクティブに
      if (currentStep === 1 && currentTime < 1 && step1Note1Active) {
        step1Note1Active = false;
      }

      // Step2の動画が2秒に達したらnote-area-item2をアクティブに
      if (currentStep === 2 && currentTime >= 2 && !step2Note2Active) {
        step2Note2Active = true;
      }

      // Step2の動画が0秒付近に戻ったら、note2を非アクティブに
      if (currentStep === 2 && currentTime < 1 && step2Note2Active) {
        step2Note2Active = false;
      }

      // Step2の動画が0秒付近に戻ったら、チャートをクリアしてフラグをリセット
      if (currentStep === 2 && currentTime < 1 && step2ChartStarted) {
        step2ChartStarted = false;
        if (d3ChartStep2Component) {
          // 軸と背景は残したまま、データのみクリア
          d3ChartStep2Component.clearData();
        }
      }

      // Step2の動画が13秒に達したら、D3チャートのアニメーションを開始
      if (
        currentStep === 2 &&
        currentTime >= 7 &&
        !step2ChartStarted &&
        d3ChartStep2Component
      ) {
        step2ChartStarted = true;
        d3ChartStep2Component.rerender();
      }

      // Step3の動画が2秒に達したらnote-area-item3をアクティブに
      if (currentStep === 3 && currentTime >= 2 && !step3Note3Active) {
        step3Note3Active = true;
      }

      // Step3の動画が0秒付近に戻ったら、note3を非アクティブに
      if (currentStep === 3 && currentTime < 1 && step3Note3Active) {
        step3Note3Active = false;
      }

      // Step3の動画が0秒付近に戻ったら、チャートをクリアしてフラグをリセット
      if (currentStep === 3 && currentTime < 1 && step3ChartStarted) {
        step3ChartStarted = false;
        if (d3ChartStep3Component) {
          // 軸と背景は残したまま、データのみクリア
          d3ChartStep3Component.clearData();
        }
      }

      // Step3の動画が7秒に達したら、D3チャートのアニメーションを開始
      if (
        currentStep === 3 &&
        currentTime >= 7 &&
        !step3ChartStarted &&
        d3ChartStep3Component
      ) {
        step3ChartStarted = true;
        d3ChartStep3Component.rerender();
      }

      // Step4の動画が2秒に達したらnote-area-item4をアクティブに
      if (currentStep === 4 && currentTime >= 2 && !step4Note4Active) {
        step4Note4Active = true;
      }

      // Step4の動画が0秒付近に戻ったら、note4を非アクティブに
      if (currentStep === 4 && currentTime < 1 && step4Note4Active) {
        step4Note4Active = false;
      }
    }
  }

  // 動画メタデータ読み込み完了
  function handleLoadedMetadata(event: Event): void {
    const video = event.target as HTMLVideoElement;
    if (video) {
      duration = video.duration || 0;
      // console.log(`動画メタデータ読み込み完了: duration=${duration}秒`);
    }
  }

  // 時間を分:秒形式にフォーマット
  function formatTime(seconds: number): string {
    if (isNaN(seconds)) return "0:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  }

  // 動画の進行度を計算（0-100%、小数点以下第四位まで）
  $: progressPercentage = (() => {
    const percentage =
      duration > 0
        ? parseFloat(((currentTime / duration) * 100).toFixed(4))
        : 0;
    // デバッグログ（最初の数回のみ表示）
    if (currentTime > 0 || duration > 0) {
      // console.log(
      //   `進捗計算: currentTime=${currentTime}, duration=${duration}, percentage=${percentage}%`,
      // );
    }
    return percentage;
  })();

  // データパネルの表示切り替え
  function toggleDataPanel(): void {
    showDataPanel = !showDataPanel;
  }

  // 最適化されたプリロード関数（static/images と static/videos を全て対象）
  async function preloadAllMedia(
    options: { includeVideos?: boolean } = {},
  ): Promise<void> {
    const { includeVideos = true } = options;

    // 進捗を初期化
    preloadProgress = 0;
    preloadStatus = "準備中...";
    let loadedCount = 0;

    // 優先度別にファイルを分類（画像は優先度を付け、残りは自動）
    const criticalFiles = [
      // 最重要：init画面で即座に必要な画像
      "/images/init-bg.svg",
      "/images/init-btn.svg",
      "/images/init-char1.webp",
      "/images/init-char2.webp",
      "/images/init-menu1-1.webp",
      "/images/init-menu1-2.webp",
      "/images/init-msg.webp",
      "/images/init-ttl.svg",
      "/images/logo.svg",
      "/images/logo.webp",
    ];

    const importantFiles = [
      // 重要：操作アイコンや最初に見える画像
      "/images/icon-play.svg",
      "/images/icon-pause.svg",
      "/images/icon-stop.svg",
      "/images/icon-prev.svg",
      "/images/icon-next.svg",
      "/images/material1.svg",
      "/images/material4.webp",
      "/images/material5.webp",
      "/images/note1.svg",
      "/images/note2.svg",
      "/images/note3.svg",
      "/images/note4.svg",
    ];

    // マニフェスト由来の全画像・全動画
    const highPrioritySet = new Set([...criticalFiles, ...importantFiles]);
    const otherImages = manifestImages.filter((p) => !highPrioritySet.has(p));
    const allVideos = [...manifestVideos];

    // 進捗計算対象の総ファイル配列（動画を含めるかはオプションに従う）
    const allFiles = includeVideos
      ? [...criticalFiles, ...importantFiles, ...otherImages, ...allVideos]
      : [...criticalFiles, ...importantFiles, ...otherImages];

    // 進捗更新関数
    const updateProgress = () => {
      loadedCount += 1;
      preloadProgress = Math.round((loadedCount / allFiles.length) * 100);

      if (loadedCount <= criticalFiles.length) {
        preloadStatus = "基本ファイル読み込み中...";
      } else if (loadedCount <= criticalFiles.length + importantFiles.length) {
        preloadStatus = "アイコンファイル読み込み中...";
      } else if (
        loadedCount <=
        criticalFiles.length + importantFiles.length + otherImages.length
      ) {
        preloadStatus = "画像読み込み中...";
      } else {
        preloadStatus = "動画読み込み中...";
      }

      // console.log(
      //   `プリロード進捗: ${loadedCount}/${allFiles.length} (${preloadProgress}%) - ${preloadStatus}`,
      // );
    };

    // ファイル読み込み関数
    const loadFile = (
      file: string,
      priority: "high" | "low" = "low",
    ): Promise<void> => {
      return new Promise<void>((resolve) => {
        // ファイル名にパスが含まれていない場合のみ追加
        const filePath = file.startsWith("/")
          ? file.endsWith(".mp4")
            ? `${videoBase}${file}`
            : `${base}${file}`
          : file.endsWith(".mp4")
            ? `${videoBase}/videos/${file}`
            : file.endsWith(".pdf")
              ? `${base}/pdfs/${file}`
              : `${base}/images/${file}`;

        if (file.endsWith(".mp4")) {
          // 動画ファイル（全てautoで完全読み込み）
          const video = document.createElement("video");
          video.preload = "auto";
          video.oncanplaythrough = () => {
            updateProgress();
            resolve();
          };
          video.onerror = () => {
            updateProgress();
            resolve();
          };
          video.src = filePath;
        } else if (file.endsWith(".pdf")) {
          // PDFファイル
          const link = document.createElement("link");
          link.rel = "prefetch";
          link.href = filePath;
          link.onload = () => {
            updateProgress();
            resolve();
          };
          link.onerror = () => {
            updateProgress();
            resolve();
          };
          document.head.appendChild(link);
        } else {
          // 画像ファイル
          const img = new Image();
          img.onload = () => {
            updateProgress();
            resolve();
          };
          img.onerror = () => {
            updateProgress();
            resolve();
          };
          img.src = filePath;
        }
      });
    };

    try {
      // 段階1: 最重要ファイル（並列読み込み）
      preloadStatus = "基本ファイル読み込み中...";
      await Promise.all(criticalFiles.map((file) => loadFile(file, "high")));

      // 段階2: 重要ファイル（並列読み込み）
      preloadStatus = "アイコンファイル読み込み中...";
      await Promise.all(importantFiles.map((file) => loadFile(file, "high")));

      // 段階3: 残り画像（並列、最大6並行）
      preloadStatus = "画像読み込み中...";
      for (let i = 0; i < otherImages.length; i += 6) {
        const batch = otherImages
          .slice(i, i + 6)
          .map((file) => loadFile(file, "high"));
        await Promise.all(batch);
      }

      if (includeVideos) {
        // 段階4: 全動画（並列読み込み、同時2本まで）
        preloadStatus = "動画読み込み中...";
        for (let i = 0; i < allVideos.length; i += 2) {
          const batch = allVideos
            .slice(i, i + 2)
            .map((file) => loadFile(file, "low"));
          await Promise.all(batch);
        }
      }

      preloadComplete = true;
      preloadStatus = "読み込み完了！";
      // console.log("すべてのメディアファイルのプリロードが完了しました");
    } catch (error) {
      console.warn("プリロード中にエラーが発生しました:", error);
      preloadComplete = true;
      preloadStatus = "読み込み完了（一部エラーあり）";
    }
  }

  // 初期化ボタンクリック時の処理
  async function handleInitButtonClick(): Promise<void> {
    isInitialized = true;

    // Tauriではフルスクリーン化
    if (isTauri) {
      try {
        const { getCurrentWindow } = await import("@tauri-apps/api/window");
        const appWindow = getCurrentWindow();
        await appWindow.setFullscreen(true);
      } catch (_) {}
    }

    // 初回表示時に全てのステップの動画を読み込むため、
    // Step2に切り替えてすぐにStep1に戻す（ユーザーには見えない速度で実行）
    await new Promise((resolve) => setTimeout(resolve, 50)); // DOMの更新を待つ

    if (videoElements.length >= 2) {
      // Step2に一瞬切り替え（動画要素を初期化）
      currentStep = 2;
      await new Promise((resolve) => setTimeout(resolve, 10));

      // Step1に戻す
      currentStep = 1;
    }
  }

  // 最初に戻るボタンクリック時の処理
  function handleHomeButtonClick(): void {
    isInitialized = false;
    // 現在の動画を停止
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentVideo.pause();
      currentVideo.currentTime = 0;
    }
    // ステップを1にリセット
    currentStep = 1;
    // データパネルを非表示に
    showDataPanel = false;
  }

  async function handleExitButtonClick(): Promise<void> {
    if (isTauri) {
      try {
        const { exit } = await import("@tauri-apps/plugin-process");
        await exit(0);
      } catch (error) {
        console.error("アプリケーションの終了に失敗しました:", error);
      }
    }
  }

  // 画像表示関数
  function showImageViewer(): void {
    showImages = true;
  }

  // 画像表示を閉じる関数
  function closeImageViewer(): void {
    showImages = false;
  }

  // 動画表示関数
  function showVideoViewer(videoFile: string): void {
    // ファイル名にパスが含まれていない場合のみ追加（ベースパス対応）
    currentVideo = videoFile.startsWith("/")
      ? `${videoBase}${videoFile}`
      : `${videoBase}/videos/${videoFile}`;
    showVideo = true;

    // 動画が読み込まれた後にコントローラーを強制表示
    setTimeout(() => {
      const videoElement = document.querySelector(
        ".video-viewer",
      ) as HTMLVideoElement;
      if (videoElement) {
        videoElement.controls = true;
        // コントローラーを強制的に表示
        videoElement.style.setProperty("--webkit-media-controls", "block");
      }
    }, 100);
  }

  // 動画表示を閉じる関数
  function closeVideoViewer(): void {
    showVideo = false;
    currentVideo = "";
  }

  // 動画を手動で再生
  function playVideo(): void {
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      // 動画が0秒付近から再生される場合、チャートアニメーションフラグをリセット
      if (currentVideo.currentTime < 1) {
        if (currentStep === 2) {
          step2ChartStarted = false;
        } else if (currentStep === 3) {
          step3ChartStarted = false;
        }
      }

      currentVideo.play();
      // 時間情報を更新
      currentTime = currentVideo.currentTime;
      duration = currentVideo.duration || 0;
    }
  }

  // 動画を手動で停止
  function pauseVideo(): void {
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentVideo.pause();
      // 時間情報を更新
      currentTime = currentVideo.currentTime;
      duration = currentVideo.duration || 0;
    }
    // 一時停止時は連続再生モードを解除
    isContinuousMode = false;
  }

  // 動画を手動で停止
  function stopVideo(): void {
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentVideo.pause();
      currentVideo.currentTime = 0;
      // 時間情報を更新
      currentTime = 0;
      duration = currentVideo.duration || 0;
    }
    // 停止時は連続再生モードを解除
    isContinuousMode = false;
  }

  // コンポーネントマウント時の処理
  onMount(async () => {
    // Tauri環境の確実な判定（複数の方法で確認）
    if (typeof window !== "undefined") {
      const win = window as any;
      isTauri =
        typeof win.__TAURI__ !== "undefined" ||
        typeof win.__TAURI_INTERNALS__ !== "undefined" ||
        typeof win.__TAURI_METADATA__ !== "undefined";
    }

    // Web: 体感速度優先（動画は後回し）
    const startPreload = () => preloadAllMedia({ includeVideos: false });
    if ("requestIdleCallback" in window) {
      (window as any).requestIdleCallback(startPreload, { timeout: 1500 });
    } else {
      setTimeout(startPreload, 300);
    }

    // 動画の最適化設定
    videoElements.forEach((video) => {
      if (video) {
        video.preload = "auto";
        video.crossOrigin = "anonymous";
        video.setAttribute("playsinline", "true");
        video.setAttribute("webkit-playsinline", "true");
      }
    });
  });

  // 動画の遅延読み込み関数
  function ensureVideoLoaded(step: number): Promise<void> {
    return new Promise((resolve) => {
      const video = videoElements[step - 1];
      if (!video) {
        resolve();
        return;
      }

      if (video.readyState >= 4) {
        // HAVE_ENOUGH_DATA - 動画が完全に読み込まれている
        resolve();
        return;
      }

      const onCanPlayThrough = () => {
        video.removeEventListener("canplaythrough", onCanPlayThrough);
        video.removeEventListener("error", onError);
        resolve();
      };

      const onError = () => {
        video.removeEventListener("canplaythrough", onCanPlayThrough);
        video.removeEventListener("error", onError);
        resolve();
      };

      video.addEventListener("canplaythrough", onCanPlayThrough);
      video.addEventListener("error", onError);

      // 動画の読み込みを開始
      video.load();
    });
  }

  // 動画を切り替える
  async function switchVideo(
    step: number,
    isAutoAdvance: boolean = false,
    forceRestart: boolean = false,
  ): Promise<void> {
    if (currentStep === step && !forceRestart) return;

    // 手動でステップを切り替えた場合は連続再生モードを解除
    // （連続再生モードで自動的に進む場合は解除しない）
    if (!isAutoAdvance) {
      isContinuousMode = false;
    }

    // 現在の動画を停止
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentVideo.pause();
      // forceRestartの場合は現在の動画も最初に戻す
      if (forceRestart && currentStep === step) {
        currentVideo.currentTime = 0;
      }
    }

    // 新しいステップに切り替え
    currentStep = step;
    const newVideo = videoElements[currentStep - 1];

    if (newVideo) {
      // 動画の読み込みを確保してから再生
      await ensureVideoLoaded(step);

      // forceRestartの場合は最初から再生
      if (forceRestart) {
        newVideo.currentTime = 0;
      }

      // 新しい動画の時間情報を更新
      currentTime = newVideo.currentTime;
      duration = newVideo.duration || 0;

      await newVideo.play();
    }

    // step1に切り替わった場合、note1フラグをリセット
    if (step === 1) {
      step1Note1Active = false;
    }

    // step2に切り替わった場合、チャートアニメーションフラグをリセット
    // （アニメーションは動画が13秒に達したときに開始される）
    if (step === 2) {
      step2ChartStarted = false;
      step2Note2Active = false; // note2もリセット
      // material動画インデックスを0（material2-1）にリセット
      materialVideoIndex[2] = 0;
      // 最初の動画は手動再生のため、自動再生はしない
    }

    // step3に切り替わった場合、チャートアニメーションフラグをリセット
    // （アニメーションは動画が7秒に達したときに開始される）
    if (step === 3) {
      step3ChartStarted = false;
      step3Note3Active = false; // note3もリセット
      // material動画インデックスを0（material3-1）にリセット
      materialVideoIndex[3] = 0;
      // 最初の動画は手動再生のため、自動再生はしない
    }

    // step4に切り替わった場合
    if (step === 4) {
      step4Note4Active = false; // note4もリセット
      // 最初の動画は手動再生のため、自動再生はしない
    }

    // step5に切り替わった場合
    if (step === 5) {
      // material動画インデックスを0（material5-1）にリセット
      materialVideoIndex[5] = 0;
      // 最初の動画は手動再生のため、自動再生はしない
    }
  }

  // 連続再生ボタンクリック時の処理
  async function continuousPlay(): Promise<void> {
    // 連続再生モードを開始
    isContinuousMode = true;
    // STEP1から開始（強制的に再生するため、forceRestartをtrueにする）
    await switchVideo(1, true, true);
  }

  // material-area内の動画を切り替える
  function switchMaterialVideo(step: number, direction: "prev" | "next"): void {
    const videos = materialVideos[step];
    if (videos.length <= 1) return;

    const currentIndex = materialVideoIndex[step];
    let newIndex = currentIndex;

    if (direction === "next") {
      newIndex = (currentIndex + 1) % videos.length;
    } else {
      newIndex = currentIndex === 0 ? videos.length - 1 : currentIndex - 1;
    }

    // オブジェクトの更新を強制的にトリガー
    materialVideoIndex = { ...materialVideoIndex, [step]: newIndex };
  }

  // 各ステップの動画要素を取得するヘルパー関数
  function getMaterialVideoElement(
    step: number,
    index: number,
  ): HTMLVideoElement | null {
    switch (step) {
      case 2:
        return index === 0
          ? material2Video1
          : index === 1
            ? material2Video2
            : null;
      case 3:
        return index === 0
          ? material3Video1
          : index === 1
            ? material3Video2
            : null;
      case 4:
        return index === 0 ? material4Video1 : null;
      case 5:
        if (index === 0) return material5Video1;
        if (index === 1) return material5Video2;
        if (index === 2) return material5Video3;
        return null;
      default:
        return null;
    }
  }

  // material動画の終了時に次の動画を自動再生（ループなし）
  function handleMaterialVideoEnded(step: number, currentIndex: number): void {
    // 連続再生モードの時は、playAllMaterialVideos関数で制御するため何もしない
    if (isContinuousMode) return;

    const videos = materialVideos[step];
    if (videos.length <= 1) return; // 動画が1本以下の場合は何もしない

    // 最後の動画の場合は何もしない（ループ再生なし）
    if (currentIndex >= videos.length - 1) return;

    // 次の動画のインデックス
    const nextIndex = currentIndex + 1;

    // 次の動画要素を取得
    const nextVideo = getMaterialVideoElement(step, nextIndex);
    if (nextVideo) {
      // インデックスを更新
      materialVideoIndex = { ...materialVideoIndex, [step]: nextIndex };
      // 次の動画を再生
      setTimeout(() => {
        nextVideo.currentTime = 0;
        nextVideo.play().catch(() => {
          // 自動再生が失敗した場合は無視
        });
      }, 100);
    }
  }
</script>

{#if !isInitialized}
  <div class="init">
    <video
      src={`${videoBase}/videos/init.mp4`}
      autoplay
      muted
      loop
      preload="auto"
      playsinline
    ></video>
    <img class="init-bg" src={asset("/images/init-bg.svg")} alt="" />
    <img class="init-ttl" src={asset("/images/init-ttl.svg")} alt="" />
    <button class="init-btn" on:click={handleInitButtonClick}>
      <img src={asset("/images/init-btn.svg")} alt="ENTER" />
    </button>
    <img class="init-char1" src={asset("/images/init-char1.webp")} alt="" />
    <img class="init-char2" src={asset("/images/init-char2.webp")} alt="" />
    <img class="init-msg" src={asset("/images/init-msg.webp")} alt="" />

    <div class="init-menu">
      <button class="init-menu1" on:click={() => showImageViewer()}
        >カタログ</button
      >
      <button
        class="init-menu2"
        on:click={() => showVideoViewer("init-menu2.mp4")}
        >土丸橋ビデオ（3分版）</button
      >
      <button
        class="init-menu3"
        on:click={() => showVideoViewer("init-menu3.mp4")}
        >土丸橋ビデオ（7分版）</button
      >
    </div>
  </div>
{/if}

{#if showImages}
  <div
    class="images-overlay"
    on:click={closeImageViewer}
    on:keydown={(e) => e.key === "Escape" && closeImageViewer()}
    role="button"
    tabindex="0"
  >
    <div
      class="images-container"
      on:click|stopPropagation
      on:keydown|stopPropagation
      role="button"
      tabindex="0"
    >
      <img
        src={asset("/images/init-menu1-1.webp")}
        alt="カタログ 1ページ目"
        class="catalog-image"
      />
      <img
        src={asset("/images/init-menu1-2.webp")}
        alt="カタログ 2ページ目"
        class="catalog-image"
      />
    </div>
  </div>
{/if}

{#if showVideo}
  <div
    class="video-overlay"
    on:click={closeVideoViewer}
    on:keydown={(e) => e.key === "Escape" && closeVideoViewer()}
    role="button"
    tabindex="0"
  >
    <div
      class="video-container"
      on:click|stopPropagation
      on:keydown|stopPropagation
      role="button"
      tabindex="0"
    >
      <!-- svelte-ignore a11y-media-has-caption -->
      <video
        bind:this={videoViewerElement}
        src={currentVideo}
        class="video-viewer"
        controls
        controlsList="nodownload"
        title="動画表示"
        preload="auto"
      ></video>
    </div>
  </div>
{/if}

<div class="stage" class:is-active={isInitialized}>
  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[0]}
    preload="auto"
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 1}
  >
    <source src={`${videoBase}/videos/step1.mp4`} type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[1]}
    preload="auto"
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 2}
  >
    <source src={`${videoBase}/videos/step2.mp4`} type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[2]}
    preload="auto"
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 3}
  >
    <source src={`${videoBase}/videos/step3.mp4`} type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[3]}
    preload="auto"
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 4}
  >
    <source src={`${videoBase}/videos/step4.mp4`} type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[4]}
    preload="auto"
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 5}
  >
    <source src={`${videoBase}/videos/step5.mp4`} type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <div class="material-area" class:is-active={currentStep === 1}>
    <img src={asset("/images/material1.svg")} alt="" />
  </div>

  <div class="material-area" class:is-active={currentStep === 2}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      bind:this={material2Video1}
      controls
      preload="auto"
      class:is-active={materialVideoIndex[2] === 0}
      on:ended={() => handleMaterialVideoEnded(2, 0)}
    >
      <source src={`${videoBase}/videos/material2-1.mp4`} type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      bind:this={material2Video2}
      controls
      preload="auto"
      class:is-active={materialVideoIndex[2] === 1}
      on:ended={() => handleMaterialVideoEnded(2, 1)}
    >
      <source src={`${videoBase}/videos/material2-2.mp4`} type="video/mp4" />
    </video>
    <div class="material-video-controls">
      <button
        on:click={() => switchMaterialVideo(2, "prev")}
        class="material-btn prev"
      >
        <img src={asset("/images/icon-prev.svg")} alt="prev" />
      </button>
      <span class="material-video-counter">{materialVideoIndex[2] + 1} / 2</span
      >
      <button
        on:click={() => switchMaterialVideo(2, "next")}
        class="material-btn next"
      >
        <img src={asset("/images/icon-next.svg")} alt="next" />
      </button>
      <div class="material-video-title">
        {materialVideoTitles[2][materialVideoIndex[2]]}
      </div>
    </div>
    <div class="graph-area">
      <D3ChartStep2 bind:this={d3ChartStep2Component} />
    </div>
  </div>

  <div class="material-area" class:is-active={currentStep === 3}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      bind:this={material3Video1}
      controls
      preload="auto"
      class:is-active={materialVideoIndex[3] === 0}
      on:ended={() => handleMaterialVideoEnded(3, 0)}
    >
      <source src={`${videoBase}/videos/material3-1.mp4`} type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      bind:this={material3Video2}
      controls
      preload="auto"
      class:is-active={materialVideoIndex[3] === 1}
      on:ended={() => handleMaterialVideoEnded(3, 1)}
    >
      <source src={`${videoBase}/videos/material3-2.mp4`} type="video/mp4" />
    </video>
    <div class="material-video-controls">
      <button
        on:click={() => switchMaterialVideo(3, "prev")}
        class="material-btn prev"
      >
        <img src={asset("/images/icon-prev.svg")} alt="prev" />
      </button>
      <span class="material-video-counter">{materialVideoIndex[3] + 1} / 2</span
      >
      <button
        on:click={() => switchMaterialVideo(3, "next")}
        class="material-btn next"
      >
        <img src={asset("/images/icon-next.svg")} alt="next" />
      </button>
      <div class="material-video-title">
        {materialVideoTitles[3][materialVideoIndex[3]]}
      </div>
    </div>
    <div class="graph-area">
      <D3ChartStep3 bind:this={d3ChartStep3Component} />
    </div>
  </div>

  <div class="material-area" class:is-active={currentStep === 4}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      bind:this={material4Video1}
      controls
      preload="auto"
      class:is-active={materialVideoIndex[4] === 0}
    >
      <source src={`${videoBase}/videos/material4-1.mp4`} type="video/mp4" />
    </video>
    <img class="material-image" src={asset("/images/material4.webp")} alt="" />
    <div class="material-video-title material-video-title4">
      {materialVideoTitles[4][materialVideoIndex[4]]}
    </div>
  </div>

  <div class="material-area" class:is-active={currentStep === 5}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      bind:this={material5Video1}
      controls
      preload="auto"
      class:is-active={materialVideoIndex[5] === 0}
      on:ended={() => handleMaterialVideoEnded(5, 0)}
    >
      <source src={`${videoBase}/videos/material5-1.mp4`} type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      bind:this={material5Video2}
      controls
      preload="auto"
      class:is-active={materialVideoIndex[5] === 1}
      on:ended={() => handleMaterialVideoEnded(5, 1)}
    >
      <source src={`${videoBase}/videos/material5-2.mp4`} type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      bind:this={material5Video3}
      controls
      preload="auto"
      class:is-active={materialVideoIndex[5] === 2}
      on:ended={() => handleMaterialVideoEnded(5, 2)}
    >
      <source src={`${videoBase}/videos/material5-3.mp4`} type="video/mp4" />
    </video>
    <div class="material-video-controls">
      <button
        on:click={() => switchMaterialVideo(5, "prev")}
        class="material-btn prev"
      >
        <img src={asset("/images/icon-prev.svg")} alt="prev" />
      </button>
      <span class="material-video-counter">{materialVideoIndex[5] + 1} / 3</span
      >
      <button
        on:click={() => switchMaterialVideo(5, "next")}
        class="material-btn next"
      >
        <img src={asset("/images/icon-next.svg")} alt="next" />
      </button>
      <div class="material-video-title">
        {materialVideoTitles[5][materialVideoIndex[5]]}
      </div>
    </div>
    <img class="material-image" src={asset("/images/material5.webp")} alt="" />
  </div>

  <div class="title-area" class:is-active={currentStep === 1}>
    <div class="title-area-item">リパッシブ工法の適用</div>
  </div>

  <div class="title-area" class:is-active={currentStep === 2}>
    <div class="title-area-item">亜硝酸リチウム水溶液の注入</div>
  </div>

  <div class="title-area" class:is-active={currentStep === 3}>
    <div class="title-area-item">エアリフト</div>
  </div>

  <div class="title-area" class:is-active={currentStep === 4}>
    <div class="title-area-item">亜硝酸リチウム水溶液の除去</div>
  </div>

  <div class="title-area" class:is-active={currentStep === 5}>
    <div class="title-area-item">グラウト再注入</div>
  </div>

  <div class="note-area" class:is-active={currentStep === 1}>
    <img
      class="note-area-item1"
      class:is-active={step1Note1Active}
      src={asset("/images/note1.svg")}
      alt=""
    />
  </div>

  <div class="note-area" class:is-active={currentStep === 2}>
    <img
      class="note-area-item2"
      class:is-active={step2Note2Active}
      src={asset("/images/note2.svg")}
      alt=""
    />
  </div>

  <div class="note-area" class:is-active={currentStep === 3}>
    <img
      class="note-area-item3"
      class:is-active={step3Note3Active}
      src={asset("/images/note3.svg")}
      alt=""
    />
  </div>

  <div class="note-area" class:is-active={currentStep === 4}>
    <img
      class="note-area-item4"
      class:is-active={step4Note4Active}
      src={asset("/images/note4.svg")}
      alt=""
    />
  </div>

  {#if showDataPanel}
    <div class="data-panel">
      <div id="content-info" class="data-panel-item step-{currentStep}">
        <p>コンテンツ</p>
        <p>STEP {currentStep}</p>
      </div>
      <div
        id="playback-status"
        class="data-panel-item {isPlaying
          ? 'playing'
          : currentTime > 0 && currentTime < duration
            ? 'paused'
            : 'stopped'}"
      >
        <p>再生状態</p>
        <p>
          {isPlaying
            ? "再生中"
            : currentTime > 0 && currentTime < duration
              ? "一時停止"
              : "停止中"}
        </p>
      </div>
      <div
        id="elapsed-time"
        class="data-panel-item"
        style="--progress: {progressPercentage}%"
      >
        <p>経過時間</p>
        <p>{formatTime(currentTime)}</p>
      </div>
      <div id="total-duration" class="data-panel-item">
        <p>総再生時間</p>
        <p>{formatTime(duration)}</p>
      </div>
      <button class="home-btn" on:click={handleHomeButtonClick}
        >最初に戻る</button
      >
      {#if isTauri}
        <button class="exit-btn" on:click={handleExitButtonClick}>終了</button>
      {/if}
    </div>
  {/if}

  <div class="control-panel">
    <div class="movie-control">
      <button id="play-btn" on:click={playVideo} class:active={isPlaying}>
        <img src={asset("/images/icon-play.svg")} alt="play" />
      </button>
      <button
        id="pause-btn"
        on:click={pauseVideo}
        class:active={!isPlaying && currentTime > 0 && currentTime < duration}
      >
        <img src={asset("/images/icon-pause.svg")} alt="pause" />
      </button>
      <button
        id="stop-btn"
        on:click={stopVideo}
        class:active={!isPlaying &&
          (currentTime === 0 || currentTime >= duration)}
      >
        <img src={asset("/images/icon-stop.svg")} alt="stop" />
      </button>
    </div>

    <div class="continuous-control">
      <button
        class="continuous-btn"
        class:active={isContinuousMode}
        on:click={continuousPlay}>連続再生</button
      >
    </div>

    <div class="step-control">
      <button on:click={() => switchVideo(1)} class:active={currentStep === 1}
        >STEP 1</button
      >
      <button on:click={() => switchVideo(2)} class:active={currentStep === 2}
        >STEP 2</button
      >
      <button on:click={() => switchVideo(3)} class:active={currentStep === 3}
        >STEP 3</button
      >
      <button on:click={() => switchVideo(4)} class:active={currentStep === 4}
        >STEP 4</button
      >
      <button on:click={() => switchVideo(5)} class:active={currentStep === 5}
        >STEP 5</button
      >
    </div>

    <div
      class="logo"
      on:click={toggleDataPanel}
      on:keydown={(e) => e.key === "Enter" && toggleDataPanel()}
      role="button"
      tabindex="0"
    >
      <img src={asset("/images/logo.svg")} alt="logo" />
    </div>
  </div>
</div>
