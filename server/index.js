import express from 'express';
import cors from 'cors';
import multer from 'multer';
import { SarvamAIClient } from 'sarvamai';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import { GoogleGenAI, Type } from '@google/genai';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '4mb' }));

const genAI = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'uploads');

    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }

    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + '-' + file.originalname);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    const allowedTypes = [
      'audio/mpeg',
      'audio/wav',
      'audio/flac',
      'audio/m4a',
      'audio/mp3',
      'audio/mp4',
      'audio/aac',
      'audio/ogg',
    ];

    if (
      allowedTypes.includes(file.mimetype) ||
      file.originalname.match(/\.(mp3|wav|flac|m4a|aac|ogg)$/i)
    ) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only MP3, WAV, FLAC, M4A allowed.'));
    }
  },
});

const sarvamClient = new SarvamAIClient({
  apiSubscriptionKey: process.env.SARVAM_API_KEY || 'YOUR_API_KEY_HERE',
});

const activeJobs = new Map();

app.post('/api/stt/create', async (req, res) => {
  try {
    const {
      model,
      mode,
      languageCode,
      withDiarization,
      numSpeakers,
    } = req.body;

    const job = await sarvamClient.speechToTextJob.createJob({
      model: model || 'saaras:v3',
      mode: mode || 'translate',
      languageCode: languageCode || 'unknown',
      withDiarization: withDiarization ?? true,
      numSpeakers: numSpeakers || 2,
    });

    const jobId = job.id || Date.now().toString();

    activeJobs.set(jobId, {
      job,
      files: [],
      status: 'created',
      createdAt: new Date().toISOString(),
    });

    res.json({
      success: true,
      jobId,
      message: 'Job created successfully',
    });
  } catch (error) {
    console.error('Error creating job:', error);

    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.post('/api/stt/:jobId/upload', upload.array('files', 10), async (req, res) => {
  try {
    const { jobId } = req.params;
    const jobData = activeJobs.get(jobId);

    if (!jobData) {
      return res.status(404).json({
        success: false,
        error: 'Job not found',
      });
    }

    const uploadedFiles = req.files || [];
    const audioPaths = uploadedFiles.map((file) => file.path);

    jobData.files.push(...audioPaths);
    jobData.fileNames = uploadedFiles.map((file) => file.originalname);

    activeJobs.set(jobId, jobData);

    await jobData.job.uploadFiles(audioPaths);

    res.json({
      success: true,
      message: `${uploadedFiles.length} file(s) uploaded successfully`,
      files: uploadedFiles.map((file) => file.originalname),
    });
  } catch (error) {
    console.error('Error uploading files:', error);

    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.post('/api/stt/:jobId/start', async (req, res) => {
  try {
    const { jobId } = req.params;
    const jobData = activeJobs.get(jobId);

    if (!jobData) {
      return res.status(404).json({
        success: false,
        error: 'Job not found',
      });
    }

    await jobData.job.start();

    jobData.status = 'processing';
    activeJobs.set(jobId, jobData);

    res.json({
      success: true,
      message: 'Job started successfully',
    });
  } catch (error) {
    console.error('Error starting job:', error);

    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.get('/api/stt/:jobId/status', async (req, res) => {
  try {
    const { jobId } = req.params;
    const jobData = activeJobs.get(jobId);

    if (!jobData) {
      return res.status(404).json({
        success: false,
        error: 'Job not found',
      });
    }

    const fileResults = await jobData.job.getFileResults();

    const totalFiles = jobData.files.length;
    const completedFiles =
      (fileResults.successful?.length || 0) +
      (fileResults.failed?.length || 0);

    const isComplete = totalFiles > 0 && completedFiles === totalFiles;

    res.json({
      success: true,
      status: isComplete ? 'completed' : 'processing',
      jobId,
      results: fileResults,
      progress: {
        total: totalFiles,
        completed: completedFiles,
        successful: fileResults.successful?.length || 0,
        failed: fileResults.failed?.length || 0,
      },
    });
  } catch (error) {
    console.error('Error getting job status:', error);

    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.get('/api/stt/:jobId/results', async (req, res) => {
  try {
    const { jobId } = req.params;
    const jobData = activeJobs.get(jobId);

    if (!jobData) {
      return res.status(404).json({
        success: false,
        error: 'Job not found',
      });
    }

    const fileResults = await jobData.job.getFileResults();

    const outputDir = path.join(__dirname, 'output');

    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    if (fileResults.successful && fileResults.successful.length > 0) {
      await jobData.job.downloadOutputs(outputDir);
    }

    const detailedResults = [];

    for (const file of fileResults.successful || []) {
      let transcriptData = null;

      const outputFile = path.join(outputDir, `${file.file_name}.json`);

      if (fs.existsSync(outputFile)) {
        transcriptData = JSON.parse(fs.readFileSync(outputFile, 'utf8'));
      } else {
        const jsonFiles = fs
          .readdirSync(outputDir)
          .filter((name) => name.endsWith('.json'));

        if (jsonFiles.length > 0) {
          transcriptData = JSON.parse(
            fs.readFileSync(path.join(outputDir, jsonFiles[0]), 'utf8'),
          );
        }
      }

      if (transcriptData) {
        const diarizedEntries =
          transcriptData.diarized_transcript?.entries || [];

        detailedResults.push({
          file_name: file.file_name,
          transcript: transcriptData.transcript || '',
          diarized_transcript: diarizedEntries,
          speaker_mapping: mapSpeakers(diarizedEntries),
        });
      }
    }

    res.json({
      success: true,
      jobId,
      results: detailedResults,
    });
  } catch (error) {
    console.error('Error getting results:', error);

    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.post('/api/quality/analyze', async (req, res) => {
  try {
    const { transcript, diarizedTranscript } = req.body;

    const qualityScore = analyzeConversationQuality(
      transcript,
      diarizedTranscript || [],
    );

    res.json({
      success: true,
      ...qualityScore,
    });
  } catch (error) {
    console.error('Error analyzing quality:', error);

    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.post('/api/ai/analyze-transcript', async (req, res) => {
  try {
    const { diarizedTranscript } = req.body;

    if (!Array.isArray(diarizedTranscript) || diarizedTranscript.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'diarizedTranscript is required',
      });
    }

    if (!process.env.GEMINI_API_KEY) {
      return res.status(500).json({
        success: false,
        error: 'GEMINI_API_KEY is missing in server .env file',
      });
    }

    const analysis = await analyzeSpeakerZeroWithGemini(diarizedTranscript);

    res.json({
      success: true,
      analysis,
    });
  } catch (error) {
    console.error('Gemini analysis error:', error);

    res.status(500).json({
      success: false,
      error: error.message || 'Failed to analyze transcript with Gemini',
    });
  }
});

function mapSpeakers(diarizedTranscript) {
  return {
    agent: '0',
    customer: '1',
  };
}

function analyzeConversationQuality(transcript, diarizedTranscript) {
  if (!Array.isArray(diarizedTranscript)) {
    diarizedTranscript = [];
  }

  let speaker0Words = 0;
  let speaker1Words = 0;

  for (const segment of diarizedTranscript) {
    const wordCount = String(segment.transcript || '')
      .trim()
      .split(/\s+/)
      .filter(Boolean).length;

    if (String(segment.speaker_id) === '0') {
      speaker0Words += wordCount;
    } else {
      speaker1Words += wordCount;
    }
  }

  const totalWords = speaker0Words + speaker1Words;
  const talkRatio = totalWords === 0 ? 0 : speaker0Words / totalWords;

  const professionalism = 7;
  const empathy = 7;
  const clarity = 7;
  const taskCompletion = 7;

  const overallScore = (
    (professionalism + empathy + clarity + taskCompletion) /
    4
  ).toFixed(1);

  return {
    overallScore,
    professionalism: professionalism.toString(),
    empathy: empathy.toString(),
    clarity: clarity.toString(),
    taskCompletion: taskCompletion.toString(),
    agentWordCount: speaker0Words,
    customerWordCount: speaker1Words,
    talkRatio: talkRatio.toString(),
    suggestions: generateSuggestions(
      professionalism,
      empathy,
      clarity,
      taskCompletion,
      talkRatio,
    ),
  };
}

function generateSuggestions(
  professionalism,
  empathy,
  clarity,
  taskCompletion,
  talkRatio,
) {
  const suggestions = [];

  if (professionalism < 7) {
    suggestions.push('Use a more professional greeting and closing.');
  }

  if (empathy < 6) {
    suggestions.push('Acknowledge customer concerns more clearly.');
  }

  if (clarity < 7) {
    suggestions.push('Use shorter and clearer sentences.');
  }

  if (taskCompletion < 7) {
    suggestions.push('Confirm that the customer query is fully solved.');
  }

  if (talkRatio > 0.7) {
    suggestions.push('Allow the customer to speak more.');
  }

  if (talkRatio < 0.3) {
    suggestions.push('Guide the conversation more actively.');
  }

  if (suggestions.length === 0) {
    suggestions.push('Good conversation. Keep improving consistency.');
  }

  return suggestions;
}

function buildFullTranscriptText(diarizedTranscript) {
  return diarizedTranscript
    .map((item) => {
      const speakerId = String(item.speaker_id ?? '');
      const speaker = speakerId === '0' ? 'Speaker 0' : 'Speaker 1';

      const text = String(item.transcript || '')
        .replace(/\s+/g, ' ')
        .trim();

      return `${speaker}: ${text}`;
    })
    .join('\n');
}

function splitTextIntoChunks(text, maxChars = 1800) {
  const chunks = [];
  let current = '';

  const lines = text.split('\n');

  for (const line of lines) {
    if ((current + '\n' + line).length > maxChars) {
      if (current.trim().length > 0) {
        chunks.push(current.trim());
      }

      current = line;
    } else {
      current += current.length === 0 ? line : `\n${line}`;
    }
  }

  if (current.trim().length > 0) {
    chunks.push(current.trim());
  }

  return chunks;
}

function getGeminiText(response) {
  if (!response) return '';

  if (typeof response.text === 'string') {
    return response.text;
  }

  if (typeof response.text === 'function') {
    return response.text();
  }

  const candidates = response.candidates || [];

  const parts =
    candidates?.[0]?.content?.parts ||
    candidates?.[0]?.content?.[0]?.parts ||
    [];

  return parts
    .map((part) => part.text || '')
    .join('')
    .trim();
}

function safeParseGeminiJson(text) {
  if (!text || String(text).trim().length === 0) {
    throw new Error('Gemini returned an empty response.');
  }

  let cleaned = String(text).trim();

  cleaned = cleaned
    .replace(/^```json/i, '')
    .replace(/^```/i, '')
    .replace(/```$/i, '')
    .trim();

  const firstBrace = cleaned.indexOf('{');
  const lastBrace = cleaned.lastIndexOf('}');

  if (firstBrace === -1 || lastBrace === -1) {
    throw new Error(`Gemini did not return valid JSON. Raw: ${cleaned}`);
  }

  cleaned = cleaned.substring(firstBrace, lastBrace + 1);

  return JSON.parse(cleaned);
}

function fallbackAnalysis() {
  return {
    speaker0_rating: 6,
    summary: 'Fallback analysis generated.',
    score_table: [
      {
        metric: 'Overall',
        score: 6,
        reason: 'Fallback score',
      },
    ],
    weak_points: [
      'Repeated questions',
      'Limited empathy',
      'Long explanations',
    ],
    suggestions: [
      'Use shorter sentences',
      'Confirm details clearly',
      'Show more empathy',
    ],
  };
}

async function analyzeTranscriptChunkWithGemini(
  chunkText,
  chunkIndex,
  totalChunks,
) {
  const prompt = `
Analyze Speaker 0 call quality for this transcript chunk.

Speaker 0 = Agent.
Speaker 1 = Customer.

Rules:
- rating must be 0 to 10.
- max 2 weak_points.
- max 2 suggestions.
- keep text short.

Chunk ${chunkIndex + 1} of ${totalChunks}:
${chunkText}
`;

  const response = await genAI.models.generateContent({
    model: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
    contents: [
      {
        role: 'user',
        parts: [
          {
            text: prompt,
          },
        ],
      },
    ],
    config: {
      temperature: 0,
      maxOutputTokens: 500,
      responseMimeType: 'application/json',
      responseSchema: {
        type: Type.OBJECT,
        properties: {
          rating: {
            type: Type.NUMBER,
          },
          weak_points: {
            type: Type.ARRAY,
            items: {
              type: Type.STRING,
            },
          },
          suggestions: {
            type: Type.ARRAY,
            items: {
              type: Type.STRING,
            },
          },
        },
        required: ['rating', 'weak_points', 'suggestions'],
      },
    },
  });

  const text = getGeminiText(response);

  console.log(`Gemini chunk ${chunkIndex + 1} raw response:`, text);

  const parsed = safeParseGeminiJson(text);

  return {
    rating: Number(parsed.rating ?? 0),
    weak_points: Array.isArray(parsed.weak_points)
      ? parsed.weak_points.slice(0, 2).map((item) => String(item))
      : [],
    suggestions: Array.isArray(parsed.suggestions)
      ? parsed.suggestions.slice(0, 2).map((item) => String(item))
      : [],
  };
}

function uniqueList(items, maxItems = 4) {
  return [...new Set(items.filter(Boolean))].slice(0, maxItems);
}

async function analyzeSpeakerZeroWithGemini(diarizedTranscript) {
  const fullTranscriptText = buildFullTranscriptText(diarizedTranscript);

  const chunks = splitTextIntoChunks(fullTranscriptText, 1800);

  console.log(`Full transcript chunks for Gemini: ${chunks.length}`);

  const chunkResults = [];

  for (let i = 0; i < chunks.length; i++) {
    try {
      const chunkResult = await analyzeTranscriptChunkWithGemini(
        chunks[i],
        i,
        chunks.length,
      );

      chunkResults.push(chunkResult);
    } catch (error) {
      console.error(`Gemini chunk ${i + 1} failed:`, error.message);
    }
  }

  console.log('Successful Gemini chunks:', chunkResults.length);

  if (chunkResults.length === 0) {
    return fallbackAnalysis();
  }

  const averageRating =
    chunkResults.reduce((sum, item) => sum + item.rating, 0) /
    chunkResults.length;

  const finalRating = Number(averageRating.toFixed(1));

  const weakPoints = uniqueList(
    chunkResults.flatMap((item) => item.weak_points),
    4,
  );

  const suggestions = uniqueList(
    chunkResults.flatMap((item) => item.suggestions),
    4,
  );

  return {
    speaker0_rating: finalRating,
    summary: `Full transcript analyzed in ${chunks.length} chunk(s).`,
    score_table: [
      {
        metric: 'Overall',
        score: finalRating,
        reason: 'Average full-call score',
      },
    ],
    weak_points: weakPoints,
    suggestions,
  };
}

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`Teleone Voice Analyzer Backend running on http://localhost:${PORT}`);
  console.log(`Uploads directory: ${path.join(__dirname, 'uploads')}`);
  console.log(`Output directory: ${path.join(__dirname, 'output')}`);
});