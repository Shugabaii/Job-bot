![Job-Bot Logo](logo.png)

# CareerPilot AI — Job-Bot Dashboard

**Professional Outreach Dashboard for Habeeb Armaya'u — Software Engineer**

CareerPilot AI is the live dashboard for Job-Bot. The bot automatically finds companies, sends professional outreach emails, and this app shows you in real-time what the bot did — sent, opened, clicked, delivered, bounced.

## Features

- **Bot Status — Live from Firebase:** Sent today, last company, last execution run
- **Metrics:** Total Sent, Open Rate, Delivered, Bounced
- **Jobs Sent — From Bot:** Real bot data from Firestore `jobs_sent`
- **Activity — Email Events:** Real Brevo events — Opened, Delivered, Clicked, Bounced
- **System Diagnostics:** Brevo, AI Engine, Firebase Sync, Firestore State

## Tech Stack

- **Flutter** — Dashboard App
- **Firebase** — Firestore + Firebase Core for live sync
- **Brevo API** — Email delivery & tracking
- **GitHub Actions** — Auto build APK on push to `main`
- **Job-Bot (Python)** — Runs on Hugging Face, sends emails, updates Firebase

## How It Works

1. **Job-Bot** finds companies and sends emails via Brevo
2. Bot saves each job to Firestore `jobs_sent` + `bot_status`
3. **CareerPilot AI App** reads Firestore + Brevo API live
4. You see everything on your phone in real-time

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
