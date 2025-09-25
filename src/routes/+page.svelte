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
  // Tauri実行判定（WebView内は __TAURI__ が存在）
  const isTauri =
    typeof window !== "undefined" &&
    typeof (window as any).__TAURI__ !== "undefined";
  // 動画用ベース
  // Tauri 時はローカルHTTPサーバーのデフォルトポートを先に使い、
  // 後で invoke 取得で上書き（初期の読み込みを速くする）
  let videoBase: string = isTauri ? "http://127.0.0.1:17820" : base;

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
  let showPdf = false; // PDF表示フラグ
  let currentPdf = ""; // 現在表示中のPDFファイル名
  let showVideo = false; // 動画表示フラグ
  let currentVideo = ""; // 現在表示中の動画ファイル名
  let preloadComplete = false; // プリロード完了フラグ
  let preloadProgress = 0; // プリロード進捗（0-100）
  let preloadStatus = "準備中..."; // プリロードステータス

  // 各material-areaの動画インデックス管理
  let materialVideoIndex: { [key: number]: number } = {
    1: 0, // material1は画像のみ
    2: 0, // material2-1.mp4, material2-2.mp4
    3: 0, // material3-1.mp4, material3-2.mp4
    4: 0, // material4-1.mp4
    5: 0, // material5-1.mp4, material5-2.mp4, material5-3.mp4
  };

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

  // 再生終了のトリガー
  function handleEnded(event: Event): void {
    const video = event.target as HTMLVideoElement;
    // console.log("動画再生終了:", event);
    // console.log("終了したステップ:", currentStep);
    isPlaying = false;

    // 動画要素から時間情報を取得
    if (video) {
      currentTime = video.currentTime;
      duration = video.duration || 0;
    }

    // 現在のステップに応じた処理例
    if (currentStep < 5) {
      // 自動で次のステップに進む場合
      // switchVideo(currentStep + 1);
    } else {
      // Step5の場合、最初に戻る
      // switchVideo(1);
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
      "/images/init-msg.png",
      "/images/init-char2.png",
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
      "/images/material4.png",
      "/images/init-bg.svg",
      "/images/init-btn.svg",
      "/images/init-ttl.svg",
      "/images/init-char1.png",
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
  }

  // 終了ボタンクリック時の処理
  function handleExitButtonClick(): void {
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

  // PDF表示関数
  function showPdfViewer(pdfFile: string): void {
    // ファイル名にパスが含まれていない場合のみ追加（ベースパス対応）
    currentPdf = pdfFile.startsWith("/")
      ? `${base}${pdfFile}`
      : `${base}/pdfs/${pdfFile}`;
    showPdf = true;
  }

  // PDF表示を閉じる関数
  function closePdfViewer(): void {
    showPdf = false;
    currentPdf = "";
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
  }

  // コンポーネントマウント時の処理
  onMount(async () => {
    if (isTauri) {
      // Tauri: ローカル動画サーバーURLを取得→全メディアをプリロード
      try {
        const { invoke } = await import("@tauri-apps/api/core");
        // サーバー起動待ち（最大 ~5 秒）
        for (let i = 0; i < 50; i++) {
          try {
            const url = (await invoke<string>("server_base_url")) as string;
            if (url) {
              videoBase = url;
              break;
            }
          } catch (_) {
            // retry shortly
          }
          await new Promise((r) => setTimeout(r, 100));
        }
      } catch (_) {}

      // 画像/動画すべてプリロード（バックグラウンドで実行）
      preloadAllMedia({ includeVideos: true });
    } else {
      // Web: 体感速度優先（動画は後回し）
      const startPreload = () => preloadAllMedia({ includeVideos: false });
      if ("requestIdleCallback" in window) {
        (window as any).requestIdleCallback(startPreload, { timeout: 1500 });
      } else {
        setTimeout(startPreload, 300);
      }
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
  async function switchVideo(step: number): Promise<void> {
    if (currentStep === step) return;

    // 現在の動画を停止
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentVideo.pause();
    }

    // 新しいステップに切り替え
    currentStep = step;
    const newVideo = videoElements[currentStep - 1];

    if (newVideo) {
      // 動画の読み込みを確保してから再生
      await ensureVideoLoaded(step);

      // 新しい動画の時間情報を更新
      currentTime = newVideo.currentTime;
      duration = newVideo.duration || 0;

      newVideo.play();
    }

    // step2に戻った場合はD3ChartStep2を再描画
    if (step === 2 && d3ChartStep2Component) {
      // 少し遅延させてから再描画（DOM更新を待つ）
      setTimeout(() => {
        d3ChartStep2Component.rerender();
      }, 100);
    }

    // step3に移動した場合はD3ChartStep3を再描画
    if (step === 3 && d3ChartStep3Component) {
      // 少し遅延させてから再描画（DOM更新を待つ）
      setTimeout(() => {
        d3ChartStep3Component.rerender();
      }, 100);
    }
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
    <img class="init-char1" src={asset("/images/init-char1.png")} alt="" />
    <img class="init-char2" src={asset("/images/init-char2.png")} alt="" />
    <img class="init-msg" src={asset("/images/init-msg.png")} alt="" />

    <div class="init-menu">
      <button
        class="init-menu1"
        on:click={() => showPdfViewer("init-menu1.pdf")}>カタログ</button
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

{#if showPdf}
  <div
    class="pdf-overlay"
    on:click={closePdfViewer}
    on:keydown={(e) => e.key === "Escape" && closePdfViewer()}
    role="button"
    tabindex="0"
  >
    <div
      class="pdf-container"
      on:click|stopPropagation
      on:keydown|stopPropagation
      role="button"
      tabindex="0"
    >
      <iframe src={currentPdf} class="pdf-viewer" title="PDF表示"></iframe>
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
        src={currentVideo}
        class="video-viewer"
        controls
        controlsList="nodownload"
        title="動画表示"
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
      controls
      preload="auto"
      class:is-active={materialVideoIndex[2] === 0}
    >
      <source src={`${videoBase}/videos/material2-1.mp4`} type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      controls
      preload="auto"
      class:is-active={materialVideoIndex[2] === 1}
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
    </div>
    <div class="graph-area">
      <D3ChartStep2 bind:this={d3ChartStep2Component} />
    </div>
  </div>

  <div class="material-area" class:is-active={currentStep === 3}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      controls
      preload="auto"
      class:is-active={materialVideoIndex[3] === 0}
    >
      <source src={`${videoBase}/videos/material3-1.mp4`} type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      controls
      preload="auto"
      class:is-active={materialVideoIndex[3] === 1}
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
    </div>
    <div class="graph-area">
      <D3ChartStep3 bind:this={d3ChartStep3Component} />
    </div>
  </div>

  <div class="material-area" class:is-active={currentStep === 4}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      controls
      preload="auto"
      class:is-active={materialVideoIndex[4] === 0}
    >
      <source src={`${videoBase}/videos/material4-1.mp4`} type="video/mp4" />
    </video>
    <img class="material-image" src={asset("/images/material4.png")} alt="" />
  </div>

  <div class="material-area" class:is-active={currentStep === 5}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      controls
      preload="auto"
      class:is-active={materialVideoIndex[5] === 0}
    >
      <source src={`${videoBase}/videos/material5-1.mp4`} type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      controls
      preload="auto"
      class:is-active={materialVideoIndex[5] === 1}
    >
      <source src={`${videoBase}/videos/material5-2.mp4`} type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video
      controls
      preload="auto"
      class:is-active={materialVideoIndex[5] === 2}
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
    </div>
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
      <button class="exit-btn" on:click={handleExitButtonClick}>EXIT</button>
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
