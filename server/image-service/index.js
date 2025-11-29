import express from "express";
import fetch from "node-fetch";
import fs from "fs";
import path from "path";
import multer from "multer";
import dotenv from "dotenv";
import ffmpeg from "fluent-ffmpeg";
import ffmpegPath from "ffmpeg-static";
import { createClient } from "@supabase/supabase-js";
import {OpenAIConfig} from "./openAI-config.js";

dotenv.config();
ffmpeg.setFfmpegPath(ffmpegPath);

const app = express();
app.use(express.json({ limit: "200mb" }));

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ROLE_KEY
);

const FRAMES_DIR = path.join(process.cwd(), "frames");
const VIDEOS_DIR = path.join(process.cwd(), "videos");

if (!fs.existsSync(FRAMES_DIR)) fs.mkdirSync(FRAMES_DIR);
if (!fs.existsSync(VIDEOS_DIR)) fs.mkdirSync(VIDEOS_DIR);

const storage = multer.diskStorage({
  destination: VIDEOS_DIR,
  filename: (_, file, cb) =>
    cb(null, `video_${Date.now()}${path.extname(file.originalname)}`)
});
const upload = multer({ storage });

app.post("/analyze-video", upload.single("videoFile"), async (req, res) => {
  let videoPath;

  try {
    if (req.file) {
      videoPath = req.file.path;
    } else if (req.body.videoUrl) {
      const videoUrl = req.body.videoUrl;
      const resp = await fetch(videoUrl);
      if (!resp.ok) throw new Error("Failed to download video");

      videoPath = path.join(VIDEOS_DIR, `video_${Date.now()}.mp4`);
      const fileStream = fs.createWriteStream(videoPath);
      await new Promise((resolve, reject) => {
        resp.body.pipe(fileStream);
        resp.body.on("error", reject);
        fileStream.on("finish", resolve);
      });
    } else {
      return res.status(400).json({ error: "videoFile or videoUrl required" });
    }

    const framesPattern = path.join(FRAMES_DIR, "frame_%03d.png");
    await new Promise((resolve, reject) => {
      ffmpeg(videoPath)
        .outputOptions(["-vf fps=1/2"])
        .output(framesPattern)
        .on("end", resolve)
        .on("error", reject)
        .run();
    });

    const frameFiles = fs.readdirSync(FRAMES_DIR).filter(f => f.endsWith(".png"));
    const frameLinks = [];

    for (const file of frameFiles) {
      const filePath = path.join(FRAMES_DIR, file);
      const fileData = fs.readFileSync(filePath);

      const { data: uploadData, error: uploadError } = await supabase.storage
        .from("frames")
        .upload(`video-frames/${Date.now()}-${file}`, fileData, {
          contentType: "image/png",
          upsert: true
        });

      if (uploadError) throw uploadError;

      const { data: { publicUrl }, error: urlError } = supabase.storage
        .from("frames")
        .getPublicUrl(uploadData.path);

      if (urlError) throw urlError;

      frameLinks.push(publicUrl);
    }

    const results = [];

    for (const link of frameLinks) {
      const openaiResp = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`
        },
        body: JSON.stringify({
          model: OpenAIConfig.MODELS.IMAGES,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: OpenAIConfig.PROMPTS.AI_DETECTION_FRAME
                },
                {
                  type: "image_url",
                  image_url: { url: link }
                }
              ]
            }
          ],
          temperature: 0
        })
      });

      const data = await openaiResp.json();
      let raw = data.choices?.[0]?.message?.content ?? "{}";

      raw = raw
        .replace(/```json/gi, "")
        .replace(/```/g, "")
        .trim();

      let parsed;
      try {
        parsed = JSON.parse(raw);
      } catch {
        parsed = {
          ai_generated: null,
          confidence: null,
          reasoning: raw
        };
      }

      results.push({ frame: link, ...parsed });
    }

    res.json({ results });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  } finally {
    fs.readdirSync(FRAMES_DIR).forEach(f =>
      fs.unlinkSync(path.join(FRAMES_DIR, f))
    );
  }
});

app.listen(3000, () => console.log("Video Analyzer running on port 3000"));
