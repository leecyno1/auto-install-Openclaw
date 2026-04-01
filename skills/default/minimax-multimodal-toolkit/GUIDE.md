# `minimax-multimodal-toolkit` 使用指南

## 作用
- MiniMax 官方多模态工具包。
- 覆盖图片生成、语音合成、视频生成、音乐生成，以及媒体处理（转码/拼接/裁剪）。

## 前置条件
- 环境变量：`MINIMAX_API_KEY`、`MINIMAX_API_HOST`
- 系统依赖：`curl`、`jq`、`ffmpeg`、`xxd`

## 常用入口
- 图片：`scripts/image/generate_image.sh`
- 语音：`scripts/tts/generate_voice.sh`
- 视频：`scripts/video/generate_video.sh`
- 音乐：`scripts/music/generate_music.sh`
- 媒体工具：`scripts/media_tools.sh`

## 快速示例
```bash
mkdir -p minimax-output
bash skills/default/minimax-multimodal-toolkit/scripts/image/generate_image.sh \
  --prompt "red and blue cyber lobster mascot" \
  -o minimax-output/lobster.png
```

```bash
bash skills/default/minimax-multimodal-toolkit/scripts/tts/generate_voice.sh \
  tts "Hello from OpenClaw" \
  -o minimax-output/hello.mp3
```

