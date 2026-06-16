# 🎙️ Voice Quality Analyst

An AI-powered **Voice Quality Analysis Web Application** that analyzes customer-agent conversations, generates speaker-wise insights, ratings, strengths, weaknesses, remarks, and quality summaries.

This project is designed for teams who want to review call quality, improve agent performance, and maintain better customer communication standards.

---

## 🚀 Project Overview

**Voice Quality Analyst** allows users to upload or process conversation audio/transcript data and analyze it using AI models such as **Sarvam AI** and **Gemini AI**.

The backend is deployed on **Render**, while the frontend can be hosted as a Flutter Web application.

---

## ✨ Key Features

✅ Upload conversation audio or transcript  
✅ Speech-to-text processing support  
✅ Speaker-wise conversation analysis  
✅ AI-based quality scoring  
✅ Weak points and strong points detection  
✅ Summary and remarks generation  
✅ Customer-agent conversation review  
✅ Backend API deployed on Render  
✅ Flutter Web dashboard support  
✅ Supports Hindi, English, and Hinglish conversations  

---

## 🧠 AI Models Used

### 🔹 Sarvam AI

Sarvam AI can be used for Indian language processing, speech-to-text, translation, and multilingual understanding.

Useful for:

- Hindi speech/text understanding
- Indian language support
- Speech-to-text workflows
- Conversation processing

### 🔹 Gemini AI

Gemini AI is used for intelligent conversation analysis and structured quality scoring.

Useful for:

- Call quality analysis
- Sentiment understanding
- Agent performance review
- JSON-based structured output
- Summary generation

---

## 🏗️ Tech Stack

### Frontend

- Flutter Web
- Dart
- Provider / State Management
- Responsive dashboard UI

### Backend

- Node.js
- Express.js
- REST API
- CORS enabled
- Render deployment

### AI Services

- Sarvam AI
- Gemini AI
- Speech-to-text pipeline
- LLM-based conversation analysis

---

## 📁 Project Structure

```bash
voice-quality-analyst/
│
├── frontend/
│   ├── lib/
│   ├── web/
│   ├── pubspec.yaml
│   └── build/
│
├── server/
│   ├── server.js
│   ├── package.json
│   ├── uploads/
│   ├── output/
│   └── .env
│
└── README.md
```

---

## ⚙️ Backend Setup

Go to the backend/server folder:

```bash
cd server
```

Install dependencies:

```bash
npm install
```

Create a `.env` file:

```env
PORT=5000
GEMINI_API_KEY=your_gemini_api_key
SARVAM_API_KEY=your_sarvam_api_key
```

Start backend locally:

```bash
npm start
```

Backend will run on:

```bash
http://localhost:5000
```

---

## 🌐 Render Backend Deployment

This project backend can be deployed easily on **Render**.

### Render Settings

| Option | Value |
|------|------|
| Environment | Node |
| Build Command | `npm install` |
| Start Command | `npm start` |
| Root Directory | `server` |
| Port | From `process.env.PORT` |

### Important

Your backend must use:

```js
const PORT = process.env.PORT || 5000;
```

Example:

```js
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

After deployment, Render will provide a live backend URL like:

```bash
https://your-service-name.onrender.com
```

Use this URL inside your Flutter Web frontend API configuration.

---

## 🧪 API Example

### Analyze Conversation

```http
POST /api/analyze
```

### Sample Request

```json
{
  "conversationText": "Speaker 0: Hello sir, how can I help you? Speaker 1: I need product details."
}
```

### Sample Response

```json
{
  "rating": 8,
  "strong": [
    "Agent greeted the customer properly",
    "Agent explained the product clearly"
  ],
  "weak": [
    "Agent could ask more follow-up questions",
    "Closing statement can be improved"
  ],
  "summary": "The agent handled the conversation well with clear communication.",
  "remark": "Good call quality with minor improvements needed."
}
```

---

## 🖥️ Frontend Setup

Go to frontend folder:

```bash
cd frontend
```

Install Flutter packages:

```bash
flutter pub get
```

Run Flutter Web locally:

```bash
flutter run -d chrome
```

Build Flutter Web:

```bash
flutter build web
```

---

## 🔗 Connecting Frontend with Render Backend

In your Flutter API service file, update the backend base URL:

```dart
const String baseUrl = "https://your-service-name.onrender.com";
```

For local testing:

```dart
const String baseUrl = "http://localhost:5000";
```

---

## 📊 Voice Quality Analysis Output

The system can generate:

- Overall rating
- Speaker-wise analysis
- Agent performance score
- Weak points
- Strong points
- Conversation summary
- Improvement suggestions
- Final remark

---

## 🎯 Use Cases

- Call center quality checking
- Sales team performance review
- Customer support analysis
- Agent training
- Voice bot testing
- Conversation auditing
- Business communication improvement

---

## 🔐 Environment Variables

Never upload your `.env` file to GitHub.

Add `.env` to `.gitignore`:

```gitignore
.env
node_modules/
uploads/
output/
```

---

## 📦 Required Dependencies

Example backend dependencies:

```json
{
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.0.0",
    "express": "^4.18.2",
    "multer": "^1.4.5"
  }
}
```

---

## 🛠️ Common Issues

### Render showing `Cannot find module server.js`

Make sure:

- `server.js` exists inside the correct backend folder
- Render root directory is correctly selected
- Start command is correct

```bash
node server.js
```

or

```bash
npm start
```

### CORS Error

Enable CORS in backend:

```js
import cors from "cors";
app.use(cors());
```

### API Not Working

Check:

- Render service is live
- Correct backend URL is used
- Environment variables are added in Render
- API route path is correct

---

## 📌 Future Improvements

- Real-time voice analysis
- Live microphone recording
- Speaker diarization
- Download PDF report
- Admin dashboard
- Agent-wise history
- Local LLM support
- Offline speech-to-text support
- Multi-language report generation

---

## 👨‍💻 Developed By

**Shantanu Singh**

Senior Mobile Developer  
Android | Flutter | AI Integration | Backend API | Voice Analysis System

---

## ⭐ Support

If this project helps you, please give it a star on GitHub.
