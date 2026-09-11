# Google Gemini & AI Platform Usage Guide

This document provides a comprehensive reference on how usage limits, quotas, pricing models, and data privacy policies differ across various **Google Gemini** surfaces and integrations used within the **Vgurukool** ecosystem.

---

## 1. Executive Summary & Comparison

All Google Gemini surfaces operate in **completely separate and isolated quota pools**. Using tokens, prompts, or messages in one surface does **not** consume your limits or impact your quotas in any of the others.

| Surface | Target Audience | How Quotas Are Measured | Typical Usage Limits | Cost Model | Impact on Other Services |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`gemini.google.com`** | Consumer Chat Web App | **Messages per hour / day** | • **Free:** ~30–50 messages / hour<br>• **Advanced:** High-velocity message caps | Free or $19.99/mo (Google One AI Premium) | **Isolated**: Does not affect API or developer tools |
| **`NotebookLM`** | Document Research & Audio Overviews | **Source count & word limits** | • Up to **50 sources per notebook**<br>• Up to **500,000 words per source**<br>• Daily audio generation limit | Free for all Google accounts | **Isolated**: Separate research product quota |
| **`Antigravity`** | Developer Desktop IDE & Coding Agent | **Context window & agent turns** | • 1,000,000+ token context window<br>• Automatic background compaction | Included with Google Developer / IDE seat | **Isolated**: Managed via Antigravity client |
| **`Configured Gemini API`** *(LiteLLM on EKS)* | Programmatic API for Applications | **RPM, TPM, and RPD** | • **Free Tier:** 15 RPM, 1M TPM, 1,500 RPD<br>• **Pay-as-you-go:** 1,000–4,000 RPM | Free tier or pay-per-million tokens ($0.075 / 1M) | **Isolated**: Bound to API key & GCP project |

---

## 2. Deep Dive by Surface

### 1. Consumer Web App (`gemini.google.com`)
* **Purpose:** General-purpose conversational assistant for web and mobile browsers.
* **Quota Tracking:** Measured in terms of prompt submissions per sliding time window (typically 3-hour or daily rolling limits).
* **Tiers:**
  * **Free:** Access to Gemini 1.5/2.0 Flash models with standard response speed and rate caps.
  * **Gemini Advanced:** $19.99/month (Google One AI Premium plan) offering priority access to Gemini 1.5 Pro and Gemini 2.0 Ultra, 1M token context window, Python code execution sandbox, and 2 TB Google Drive storage.
* **Data Privacy:** On the free tier, conversations may be reviewed by trained human annotators to improve Google products unless explicitly disabled under **Gemini Apps Activity**.

---

### 2. NotebookLM (`notebooklm.google.com`)
* **Purpose:** Source-grounded AI research assistant for distilling notes, PDFs, Google Docs, and web links.
* **Quota Tracking:** NotebookLM does **not** track token consumption or bill per request. It enforces content volume boundaries:
  * Up to **100 notebooks** per user.
  * Up to **50 sources** per notebook.
  * Up to **500,000 words** per source (approx. 250 MB per source).
  * Rate-limited daily generations for **Audio Overviews** ("Deep Dive" podcast discussions).
* **Cost:** Free for personal, enterprise, and educational Google accounts.
* **Data Privacy:** Your uploaded documents and notes are **not** used to train Google's models.

---

### 3. Antigravity (Desktop IDE & Coding Agent)
* **Purpose:** Autonomous AI pair programmer, codebase architect, and local development platform.
* **Quota Tracking:**
  * Powered by developer-tier Gemini models (Gemini Pro & Gemini Flash).
  * Supports an active **1,000,000+ token context window** allowing the agent to read multiple full files, git diffs, and terminal outputs concurrently.
  * **Automatic Compaction:** When session transcripts grow extensive, Antigravity generates structured `<CONTEXT_SUMMARY>` checkpoints in the background to preserve responsiveness and prevent context overflow.
* **Model Configuration:**
  * Selectable under **Settings** $\rightarrow$ **Global Settings** $\rightarrow$ **Model Selection**:
    * **Gemini Pro (Default):** Deep multi-step reasoning, architectural changes, and comprehensive debugging.
    * **Gemini Flash:** Fast responses, token efficiency, and light code tweaks.
* **Cost & Quota:** Provided through your Google developer seat; does not draw down personal Google AI Studio credits or credit card balances.

---

### 4. Configured Gemini API (LiteLLM Gateway on EKS)
* **Purpose:** Programmatic backend LLM router serving cluster applications (CAIPE dynamic agents, LearnHouse LMS, MAIC UI).
* **Architecture:** Calls Google Gemini endpoints (`gemini-2.5-flash`, `gemini-1.5-flash`, `gemini-1.5-pro`) using the `GEMINI_API_KEY` injected into the `litellm` Kubernetes namespace.
* **Quota Tracking & Rate Limits:**
  * **Google AI Studio Free Tier:**
    * **15 RPM** (Requests Per Minute)
    * **1,000,000 TPM** (Tokens Per Minute)
    * **1,500 RPD** (Requests Per Day)
  * **Pay-As-You-Go Plan (Tier 1 / Vertex AI):**
    * **1,000 to 4,000 RPM**
    * **4,000,000+ TPM**
    * Pricing (approximate for Gemini 1.5 Flash): **$0.075 / 1M input tokens** and **$0.30 / 1M output tokens**.
* **Data Privacy:** Pay-as-you-go and Vertex AI API data is strictly confidential and is **never** used to train foundation models.

---

## 3. Monitoring & Management Dashboards

| Service | Monitoring Dashboard | What You Can View |
| :--- | :--- | :--- |
| **Vgurukool LiteLLM** | [https://litellm.vgurukool.com/ui/](https://litellm.vgurukool.com/ui/) | Real-time token counts, request latency, model distribution, and spend per application key. |
| **Google AI Studio** | [https://aistudio.google.com/](https://aistudio.google.com/) | API keys, active rate limits, remaining free tier requests, and project usage graphs. |
| **Google Cloud Vertex AI** | [https://console.cloud.google.com/vertex-ai](https://console.cloud.google.com/vertex-ai) | Enterprise quotas, IAM access policies, billing alerts, and model evaluation metrics. |
| **Antigravity IDE** | Settings $\rightarrow$ Model Selection | Active model selection, sandbox execution rules, and subagent resource permissions. |

---

## 4. Key Takeaways

1. **Zero Cross-Service Cannibalization:** Heavy usage of `gemini.google.com` or `NotebookLM` will never throttle your `LiteLLM` agents on the EKS cluster or block your `Antigravity` coding session.
2. **Cost Predictability:**
   * NotebookLM, Antigravity, and `gemini.google.com` (free) carry **zero variable token billing**.
   * Only the **Configured Gemini API** on LiteLLM (if switched from AI Studio Free Tier to Paid Tier) incurs usage-based token charges on Google Cloud.
3. **Cluster Isolation:** Even if cluster compute nodes are hibernated (`bash scripts/hibernate.sh`), external services like Antigravity, NotebookLM, and `gemini.google.com` remain 100% available since they run on Google's global cloud infrastructure.
