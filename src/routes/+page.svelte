<script lang="ts">
  import "../app.css";
  import { SIGNAGE_VERSION } from "$lib";
  import D3ChartStep2 from "$lib/D3ChartStep2.svelte";
  import D3ChartStep3 from "$lib/D3ChartStep3.svelte";

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
    console.log("動画再生開始:", event);
    isPlaying = true;
    playCount++;
    // ここに再生開始時の処理を書く
  }

  // 再生終了のトリガー
  function handleEnded(event: Event): void {
    console.log("動画再生終了:", event);
    console.log("終了したステップ:", currentStep);
    isPlaying = false;

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
    console.log("動画一時停止:", event);
    isPlaying = false;
  }

  // 時間更新のトリガー
  function handleTimeUpdate(event: Event): void {
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentTime = currentVideo.currentTime;
      duration = currentVideo.duration || 0;
    }
  }

  // 動画メタデータ読み込み完了
  function handleLoadedMetadata(event: Event): void {
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      duration = currentVideo.duration || 0;
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
  $: progressPercentage =
    duration > 0 ? parseFloat(((currentTime / duration) * 100).toFixed(4)) : 0;

  // データパネルの表示切り替え
  function toggleDataPanel(): void {
    showDataPanel = !showDataPanel;
  }

  // 初期化ボタンクリック時の処理
  function handleInitButtonClick(): void {
    isInitialized = true;
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

  // 動画を手動で再生
  function playVideo(): void {
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentVideo.play();
    }
  }

  // 動画を手動で停止
  function pauseVideo(): void {
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentVideo.pause();
    }
  }

  // 動画を手動で停止
  function stopVideo(): void {
    const currentVideo = videoElements[currentStep - 1];
    if (currentVideo) {
      currentVideo.pause();
      currentVideo.currentTime = 0;
    }
  }

  // 動画を切り替える
  function switchVideo(step: number): void {
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
      // 新しい動画を読み込んで自動再生
      newVideo.load();
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
    <video src="/videos/init.mp4" autoplay muted loop></video>
    <img class="init-bg" src="/images/init-bg.svg" alt="" />
    <img class="init-ttl" src="/images/init-ttl.svg" alt="" />
    <button class="init-btn" on:click={handleInitButtonClick}>
      <img src="/images/init-btn.svg" alt="ENTER" />
    </button>
  </div>
{/if}

<div class="stage" class:is-active={isInitialized}>
  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[0]}
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 1}
  >
    <source src="/videos/step1.mp4" type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[1]}
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 2}
  >
    <source src="/videos/step2.mp4" type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[2]}
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 3}
  >
    <source src="/videos/step3.mp4" type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[3]}
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 4}
  >
    <source src="/videos/step4.mp4" type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElements[4]}
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
    class:is-active={currentStep === 5}
  >
    <source src="/videos/step5.mp4" type="video/mp4" />
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  <div class="material-area" class:is-active={currentStep === 1}>
    <img src="/images/material1.svg" alt="" />
  </div>

  <div class="material-area" class:is-active={currentStep === 2}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video controls class:is-active={materialVideoIndex[2] === 0}>
      <source src="/videos/material2-1.mp4" type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video controls class:is-active={materialVideoIndex[2] === 1}>
      <source src="/videos/material2-2.mp4" type="video/mp4" />
    </video>
    <div class="material-video-controls">
      <button
        on:click={() => switchMaterialVideo(2, "prev")}
        class="material-btn prev"
      >
        <img src="/images/icon-prev.svg" alt="prev" />
      </button>
      <span class="material-video-counter">{materialVideoIndex[2] + 1} / 2</span
      >
      <button
        on:click={() => switchMaterialVideo(2, "next")}
        class="material-btn next"
      >
        <img src="/images/icon-next.svg" alt="next" />
      </button>
    </div>
    <div class="graph-area">
      <D3ChartStep2 bind:this={d3ChartStep2Component} />
    </div>
  </div>

  <div class="material-area" class:is-active={currentStep === 3}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video controls class:is-active={materialVideoIndex[3] === 0}>
      <source src="/videos/material3-1.mp4" type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video controls class:is-active={materialVideoIndex[3] === 1}>
      <source src="/videos/material3-2.mp4" type="video/mp4" />
    </video>
    <div class="material-video-controls">
      <button
        on:click={() => switchMaterialVideo(3, "prev")}
        class="material-btn prev"
      >
        <img src="/images/icon-prev.svg" alt="prev" />
      </button>
      <span class="material-video-counter">{materialVideoIndex[3] + 1} / 2</span
      >
      <button
        on:click={() => switchMaterialVideo(3, "next")}
        class="material-btn next"
      >
        <img src="/images/icon-next.svg" alt="next" />
      </button>
    </div>
    <div class="graph-area">
      <D3ChartStep3 bind:this={d3ChartStep3Component} />
    </div>
  </div>

  <div class="material-area" class:is-active={currentStep === 4}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video controls class:is-active={materialVideoIndex[4] === 0}>
      <source src="/videos/material4-1.mp4" type="video/mp4" />
    </video>
    <img class="material-image" src="/images/material4.png" alt="" />
  </div>

  <div class="material-area" class:is-active={currentStep === 5}>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video controls class:is-active={materialVideoIndex[5] === 0}>
      <source src="/videos/material5-1.mp4" type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video controls class:is-active={materialVideoIndex[5] === 1}>
      <source src="/videos/material5-2.mp4" type="video/mp4" />
    </video>
    <!-- svelte-ignore a11y-media-has-caption -->
    <video controls class:is-active={materialVideoIndex[5] === 2}>
      <source src="/videos/material5-3.mp4" type="video/mp4" />
    </video>
    <div class="material-video-controls">
      <button
        on:click={() => switchMaterialVideo(5, "prev")}
        class="material-btn prev"
      >
        <img src="/images/icon-prev.svg" alt="prev" />
      </button>
      <span class="material-video-counter">{materialVideoIndex[5] + 1} / 3</span
      >
      <button
        on:click={() => switchMaterialVideo(5, "next")}
        class="material-btn next"
      >
        <img src="/images/icon-next.svg" alt="next" />
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
        <img src="/images/icon-play.svg" alt="play" />
      </button>
      <button
        id="pause-btn"
        on:click={pauseVideo}
        class:active={!isPlaying && currentTime > 0 && currentTime < duration}
      >
        <img src="/images/icon-pause.svg" alt="pause" />
      </button>
      <button
        id="stop-btn"
        on:click={stopVideo}
        class:active={!isPlaying &&
          (currentTime === 0 || currentTime >= duration)}
      >
        <img src="/images/icon-stop.svg" alt="stop" />
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
      <img src="/images/logo.svg" alt="logo" />
    </div>
  </div>
</div>
