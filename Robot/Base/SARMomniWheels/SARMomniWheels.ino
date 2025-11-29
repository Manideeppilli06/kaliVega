#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

// Motor pins (direction)
int M1A = 23, M1B = 22;
int M2A = 21, M2B = 19;
int M3A = 14, M3B = 15;
int M4A = 2,  M4B = 0;

// Enable pins (PWM speed control)
int EN1 = 33, EN2 = 32;
int EN3 = 12, EN4 = 4;

// Base speed (0–255)
int baseSpeed = 180;

// Movement timing - INCREASED for press-and-hold support
unsigned long lastCommandTime = 0;
unsigned long commandTimeout = 500; // Stop if no command for 500ms
bool isMoving = false;

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println();
  Serial.println("=================================");
  Serial.println("OMNI ROBOT STARTING...");
  Serial.println("=================================");

  // Start Bluetooth
  SerialBT.begin("SARM_OMNI_BT");
  Serial.println("✓ Bluetooth started: SARM_OMNI_BT");

  // Direction pins
  pinMode(M1A, OUTPUT); pinMode(M1B, OUTPUT);
  pinMode(M2A, OUTPUT); pinMode(M2B, OUTPUT);
  pinMode(M3A, OUTPUT); pinMode(M3B, OUTPUT);
  pinMode(M4A, OUTPUT); pinMode(M4B, OUTPUT);

  // Enable pins
  pinMode(EN1, OUTPUT); pinMode(EN2, OUTPUT);
  pinMode(EN3, OUTPUT); pinMode(EN4, OUTPUT);

  // Set initial speed
  setSpeed(baseSpeed);
  stopAll();

  Serial.println("✓ Motors initialized");
  Serial.println("=================================");
  Serial.println("Press-and-hold mode enabled");
  Serial.println("Commands: F,B,L,R,CW,CCW,FL,FR,BL,BR,S");
  Serial.println("Speed: SPD <0-255>");
  Serial.println("=================================");
}

// ---------------- SPEED FUNCTION ----------------
void setSpeed(int s) {
  baseSpeed = constrain(s, 0, 255);
  analogWrite(EN1, baseSpeed);
  analogWrite(EN2, baseSpeed);
  analogWrite(EN3, baseSpeed);
  analogWrite(EN4, baseSpeed);
  Serial.print("⚡ Speed: ");
  Serial.println(baseSpeed);
}

// ---------------- STOP ----------------
void stopAll() {
  digitalWrite(M1A, LOW); digitalWrite(M1B, LOW);
  digitalWrite(M2A, LOW); digitalWrite(M2B, LOW);
  digitalWrite(M3A, LOW); digitalWrite(M3B, LOW);
  digitalWrite(M4A, LOW); digitalWrite(M4B, LOW);
  isMoving = false;
}

// ---------------- MOVEMENTS ----------------
void forward() {
  digitalWrite(M1A, HIGH); digitalWrite(M1B, LOW);
  digitalWrite(M2A, HIGH); digitalWrite(M2B, LOW);
  digitalWrite(M3A, HIGH); digitalWrite(M3B, LOW);
  digitalWrite(M4A, HIGH); digitalWrite(M4B, LOW);
  isMoving = true;
  lastCommandTime = millis();
}

void backward() {
  digitalWrite(M1A, LOW); digitalWrite(M1B, HIGH);
  digitalWrite(M2A, LOW); digitalWrite(M2B, HIGH);
  digitalWrite(M3A, LOW); digitalWrite(M3B, HIGH);
  digitalWrite(M4A, LOW); digitalWrite(M4B, HIGH);
  isMoving = true;
  lastCommandTime = millis();
}

void leftMove() {
  digitalWrite(M1A, LOW);  digitalWrite(M1B, HIGH);
  digitalWrite(M2A, HIGH); digitalWrite(M2B, LOW);
  digitalWrite(M3A, HIGH); digitalWrite(M3B, LOW);
  digitalWrite(M4A, LOW);  digitalWrite(M4B, HIGH);
  isMoving = true;
  lastCommandTime = millis();
}

void rightMove() {
  digitalWrite(M1A, HIGH); digitalWrite(M1B, LOW);
  digitalWrite(M2A, LOW);  digitalWrite(M2B, HIGH);
  digitalWrite(M3A, LOW);  digitalWrite(M3B, HIGH);
  digitalWrite(M4A, HIGH); digitalWrite(M4B, LOW);
  isMoving = true;
  lastCommandTime = millis();
}

void rotateCW() {
  digitalWrite(M1A, HIGH); digitalWrite(M1B, LOW);
  digitalWrite(M2A, LOW);  digitalWrite(M2B, HIGH);
  digitalWrite(M3A, HIGH); digitalWrite(M3B, LOW);
  digitalWrite(M4A, LOW);  digitalWrite(M4B, HIGH);
  isMoving = true;
  lastCommandTime = millis();
}

void rotateCCW() {
  digitalWrite(M1A, LOW);  digitalWrite(M1B, HIGH);
  digitalWrite(M2A, HIGH); digitalWrite(M2B, LOW);
  digitalWrite(M3A, LOW);  digitalWrite(M3B, HIGH);
  digitalWrite(M4A, HIGH); digitalWrite(M4B, LOW);
  isMoving = true;
  lastCommandTime = millis();
}

void forwardLeft() {
  stopAll();
  digitalWrite(M2A, HIGH); digitalWrite(M2B, LOW);
  digitalWrite(M4A, HIGH); digitalWrite(M4B, LOW);
  isMoving = true;
  lastCommandTime = millis();
}

void forwardRight() {
  stopAll();
  digitalWrite(M1A, HIGH); digitalWrite(M1B, LOW);
  digitalWrite(M3A, HIGH); digitalWrite(M3B, LOW);
  isMoving = true;
  lastCommandTime = millis();
}

void backwardLeft() {
  stopAll();
  digitalWrite(M1A, LOW); digitalWrite(M1B, HIGH);
  digitalWrite(M3A, LOW); digitalWrite(M3B, HIGH);
  isMoving = true;
  lastCommandTime = millis();
}

void backwardRight() {
  stopAll();
  digitalWrite(M2A, LOW); digitalWrite(M2B, HIGH);
  digitalWrite(M4A, LOW); digitalWrite(M4B, HIGH);
  isMoving = true;
  lastCommandTime = millis();
}

// ---------------- COMMAND PARSE & HANDLE ----------------
String readCommandFromSerial() {
  if (Serial.available()) {
    String s = Serial.readStringUntil('\n');
    s.trim();
    s.toUpperCase();
    return s;
  }
  return "";
}

String readCommandFromBT() {
  if (SerialBT.available()) {
    String s = SerialBT.readStringUntil('\n');
    s.trim();
    s.toUpperCase();
    return s;
  }
  return "";
}

void handleCommand(String cmd) {
  if (cmd.length() == 0) return;

  // Speed command
  if (cmd.startsWith("SPD")) {
    String num = cmd.substring(3);
    num.trim();
    int val = num.toInt();
    if (val >= 0 && val <= 255) {
      setSpeed(val);
      SerialBT.println("Speed: " + String(baseSpeed));
    }
    return;
  }

  // Movement commands - now support continuous hold
  if      (cmd == "F")   { Serial.println("▲"); forward(); }
  else if (cmd == "B")   { Serial.println("▼"); backward(); }
  else if (cmd == "L")   { Serial.println("◄"); leftMove(); }
  else if (cmd == "R")   { Serial.println("►"); rightMove(); }
  else if (cmd == "CW")  { Serial.println("↻"); rotateCW(); }
  else if (cmd == "CCW") { Serial.println("↺"); rotateCCW(); }
  else if (cmd == "FL")  { Serial.println("↖"); forwardLeft(); }
  else if (cmd == "FR")  { Serial.println("↗"); forwardRight(); }
  else if (cmd == "BL")  { Serial.println("↙"); backwardLeft(); }
  else if (cmd == "BR")  { Serial.println("↘"); backwardRight(); }
  else if (cmd == "S")   { Serial.println("■"); stopAll(); }
}

// Track connection status
bool wasConnected = false;

void loop() {
  // Auto-stop ONLY if no commands received for timeout period
  // This allows press-and-hold to work (Flutter sends every 100ms)
  if (isMoving && (millis() - lastCommandTime > commandTimeout)) {
    Serial.println("⚠ Timeout - stopping");
    stopAll();
  }

  // Check connection status
  bool nowConnected = SerialBT.hasClient();
  if (nowConnected && !wasConnected) {
    Serial.println("✓ CONNECTED!");
    stopAll();
  } else if (!nowConnected && wasConnected) {
    Serial.println("✗ DISCONNECTED!");
    stopAll();
  }
  wasConnected = nowConnected;

  // Check USB Serial
  String cmd = readCommandFromSerial();
  if (cmd.length()) {
    handleCommand(cmd);
    return;
  }

  // Check Bluetooth Serial
  cmd = readCommandFromBT();
  if (cmd.length()) {
    handleCommand(cmd);
    return;
  }
}