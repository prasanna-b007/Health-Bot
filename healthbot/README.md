# HealthBot

This is a Rasa-based chatbot project. 

## Setup Instructions

### 1. Prerequisites
Ensure you have Python installed (Python 3.7 - 3.10 is recommended for Rasa 3.x).

### 2. Prepare Virtual Environment
It is highly recommended to use a virtual environment to manage dependencies. From the root of the project (`healthbot` directory), run:

```powershell
python -m venv venv
```

Activate the environment:
* On Windows (Powershell):
  ```powershell
  .\venv\Scripts\activate
  ```
* On macOS/Linux:
  ```bash
  source venv/bin/activate
  ```

### 3. Install Dependencies
Install Rasa using pip. Be patient as this will install large machine learning dependencies like TensorFlow:

```powershell
pip install rasa
```

## Running the Bot

To run your Rasa assistant, follow these steps:

### 1. Run the Actions Server
In your first terminal window (with the virtual environment activated), start the custom actions server:

```powershell
rasa run actions
```

### 2. Run the Chatbot Shell
Open a **second terminal window**, activate your virtual environment again, and run the chatbot interface:

```powershell
# Reactivate environment in the new pane/terminal
.\venv\Scripts\activate

# Start the rasa shell
rasa shell
```

**Note:** If you make changes to your intents in `data/nlu.yml` or your configurations in `domain.yml`/`config.yml`, make sure to retrain your model before running the shell by using:
```powershell
rasa train
```

---

*For running custom Python scripts in the `scratch/` directory, simply run them via Python, making sure you execute them from the project's root folder:*
```powershell
python scratch/full_audit.py
```

# Health-Bot
cd d:\Projects\Health-Bot\healthbot
.\venv\Scripts\activate
rasa run actions

cd d:\Projects\Health-Bot\healthbot
.\venv\Scripts\activate
rasa run --enable-api --cors "*" --port 5005

cd d:\Projects\Health-Bot\health_bot_app
flutter pub get
flutter run
