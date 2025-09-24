#!/bin/bash

# 動画ファイルの最適化スクリプト
# FFmpegを使用して動画を圧縮し、読み込み速度を向上させます

echo "動画ファイルの最適化を開始します..."

# 出力ディレクトリを作成
mkdir -p static/videos/optimized

# 最適化設定
QUALITY="23"  # CRF値（18-28が推奨、低いほど高品質）
PRESET="medium"  # エンコード速度（ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow）
MAX_WIDTH="1920"  # 最大幅
MAX_HEIGHT="1080"  # 最大高さ

# 動画ファイルのリスト
VIDEOS=(
    "static/videos/step1.mp4"
    "static/videos/step2.mp4"
    "static/videos/step3.mp4"
    "static/videos/step4.mp4"
    "static/videos/step5.mp4"
    "static/videos/material2-1.mp4"
    "static/videos/material2-2.mp4"
    "static/videos/material3-1.mp4"
    "static/videos/material3-2.mp4"
    "static/videos/material4-1.mp4"
    "static/videos/material5-1.mp4"
    "static/videos/material5-2.mp4"
    "static/videos/material5-3.mp4"
)

# 各動画ファイルを最適化
for video in "${VIDEOS[@]}"; do
    if [ -f "$video" ]; then
        filename=$(basename "$video")
        output="static/videos/optimized/$filename"
        
        echo "最適化中: $filename"
        
        # FFmpegで動画を最適化
        ffmpeg -i "$video" \
            -c:v libx264 \
            -crf $QUALITY \
            -preset $PRESET \
            -c:a aac \
            -b:a 128k \
            -vf "scale=min($MAX_WIDTH,iw):min($MAX_HEIGHT,ih):force_original_aspect_ratio=decrease" \
            -movflags +faststart \
            -y \
            "$output"
        
        # ファイルサイズを比較
        original_size=$(stat -f%z "$video" 2>/dev/null || stat -c%s "$video" 2>/dev/null)
        optimized_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
        
        if [ -n "$original_size" ] && [ -n "$optimized_size" ]; then
            reduction=$(( (original_size - optimized_size) * 100 / original_size ))
            echo "  元のサイズ: $(numfmt --to=iec $original_size)"
            echo "  最適化後: $(numfmt --to=iec $optimized_size)"
            echo "  削減率: ${reduction}%"
        fi
        
        echo "完了: $filename"
        echo ""
    else
        echo "ファイルが見つかりません: $video"
    fi
done

echo "動画の最適化が完了しました！"
echo "最適化されたファイルは static/videos/optimized/ に保存されています。"
echo ""
echo "使用方法:"
echo "1. 最適化されたファイルを確認してください"
echo "2. 問題がなければ、元のファイルと置き換えてください"
echo "3. 元のファイルはバックアップとして保持することをお勧めします"
