# 🗣️ Echo Notes

**Echo Notes** is a simple yet powerful Flutter application that leverages the **Groq API** and **Google integration** to help users transcribe, understand, and act on their conversations.

---

## ✨ Features

- 🎙️ **Audio to Text**  
  Converts spoken audio into text using speech recognition.

- 🤖 **Groq AI Conversation Insights**  
  Uses **Groq's blazing-fast language models** to analyze conversations in context:

  - 🧠 Academic
  - 💞 Romantic
  - 🗣️ Regular/Informal

- 💡 **Smart Suggestions**  
  Based on the type of conversation, the app can:

  - Summarize it into a concise, clear version
  - Suggest a reply (especially useful for romantic chats)

- 📄 **Google Integration**  
  Connects to the user's Google account and lets them:
  - Push summarized conversations to Google Docs
  - Automatically organize and store notes in Drive

---

## 🚀 Tech Stack

- **Flutter** — Cross-platform UI framework
- **Groq API** — AI model for real-time conversation analysis and prompt generation
- **Google Sign-In** — Auth & Docs access
- **Speech-to-Text** — For live audio transcription
- **Riverpod** — State management
- **Flutter Secure Storage** — Token handling

---

## 🛠️ Setup & Installation

> ⚠️ Make sure you've configured:
>
> - Google Cloud Console with OAuth, Docs, and Drive access
> - A valid Groq API key ([Groq Developer Portal](https://console.groq.com/))

```bash
# Clone the repo
git clone https://github.com/your-username/echo-notes.git
cd echo-notes

# Set up environment variables
cp .env.example .env
# Add your GOOGLE_CLIENT_ID, GOOGLE_SERVER_CLIENT_ID, and GROQ_API_KEY in .env

# Install dependencies
flutter pub get

# Run the app
flutter run
```
