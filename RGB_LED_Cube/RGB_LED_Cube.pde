// 8x8x8 RGB LED キューブのためのコントローラー
// シリアル通信で [LEDの番号, R, G, B] の形式で制御
// マウスドラッグでキューブを回転できる機能付き

import processing.serial.*;

// シリアル通信設定
Serial myPort;
final int BAUD_RATE = 115200;

// LEDキューブの設定
final int CUBE_SIZE = 8;
final int NUM_LEDS = CUBE_SIZE * CUBE_SIZE * CUBE_SIZE;

// LED の色情報を格納する配列
byte[] ledColors = new byte[NUM_LEDS * 3]; // R, G, B の3バイト × 512個のLED

// キューブの描画パラメータ
float cubeSize = 400;
float ledSize;
float spacing;

// 回転パラメータ
float rotX = QUARTER_PI;
float rotY = QUARTER_PI;
float prevMouseX, prevMouseY;
boolean isDragging = false;

void setup() {
  size(800, 800, P3D);
  
  // LED サイズと間隔の計算
  ledSize = cubeSize / (CUBE_SIZE * 4);
  spacing = cubeSize / CUBE_SIZE;
  
  // シリアルポートの初期化
  println("利用可能なシリアルポート:");
  printArray(Serial.list());
  
  // 使用可能なポートがあるか確認
  if (Serial.list().length > 0) {
    // 最初のポートを使用（実際の環境に合わせて変更してください）
    String portName = "/dev/cu.usbserial-14340";//Serial.list()[0];
    myPort = new Serial(this, portName, BAUD_RATE);
    myPort.bufferUntil('\n');
    println("ポート接続: " + portName);
  } else {
    println("警告: 利用可能なシリアルポートが見つかりません。シミュレーションモードで実行します。");
  }
  
  // LED の色を初期化（すべて消灯）
  for (int i = 0; i < ledColors.length; i++) {
    ledColors[i] = 0;
  }
}

void draw() {
  background(0);
  
  // 視点の設定
  translate(width/2, height/2, 0);
  // ユーザーの回転操作を適用
  rotateX(rotX);
  rotateY(rotY);
  
  // キューブの中心を原点に
  translate(-cubeSize/2, -cubeSize/2, -cubeSize/2);
  
  // LED キューブの描画
  for (int x = 0; x < CUBE_SIZE; x++) {
    for (int y = 0; y < CUBE_SIZE; y++) {
      for (int z = 0; z < CUBE_SIZE; z++) {
        int ledIndex = getLedIndex(x, y, z);
        int colorIndex = ledIndex * 3;
        
        // LED の色取得
        int r = ledColors[colorIndex] & 0xFF;
        int g = ledColors[colorIndex + 1] & 0xFF;
        int b = ledColors[colorIndex + 2] & 0xFF;
        
        // LED が点灯している場合のみ描画
        if (r > 0 || g > 0 || b > 0) {
          pushMatrix();
          translate(x * spacing, y * spacing, z * spacing);
          fill(r, g, b);
          noStroke();
          sphere(ledSize);
          popMatrix();
        }
      }
    }
  }
  
  // キューブのワイヤーフレーム描画
  drawCubeFrame();
}

// キューブのワイヤーフレームを描画
void drawCubeFrame() {
  stroke(50);
  noFill();
  
  // 外枠の描画
  //pushMatrix();
  //box(cubeSize);
  //popMatrix();
  
  // グリッド線の描画
  stroke(30);
  for (int i = 1; i < CUBE_SIZE; i++) {
    float pos = i * spacing;
    
    // X軸に平行なライン
    for (int j = 0; j < CUBE_SIZE; j++) {
      line(0, pos, j * spacing, cubeSize, pos, j * spacing);
      line(0, j * spacing, pos, cubeSize, j * spacing, pos);
    }
    
    // Y軸に平行なライン
    for (int j = 0; j < CUBE_SIZE; j++) {
      line(pos, 0, j * spacing, pos, cubeSize, j * spacing);
      line(j * spacing, 0, pos, j * spacing, cubeSize, pos);
    }
    
    // Z軸に平行なライン
    for (int j = 0; j < CUBE_SIZE; j++) {
      line(pos, j * spacing, 0, pos, j * spacing, cubeSize);
      line(j * spacing, pos, 0, j * spacing, pos, cubeSize);
    }
  }
}

// 座標から LED インデックスを計算
int getLedIndex(int x, int y, int z) {
  return (z * CUBE_SIZE * CUBE_SIZE) + (y * CUBE_SIZE) + x;
}

// LED インデックスから座標を計算
PVector getLedPosition(int index) {
  int z = index / (CUBE_SIZE * CUBE_SIZE);
  int remainder = index % (CUBE_SIZE * CUBE_SIZE);
  int y = remainder / CUBE_SIZE;
  int x = remainder % CUBE_SIZE;
  return new PVector(x, y, z);
}

// シリアルポートからデータを受信したときに呼ばれる
void serialEvent(Serial port) {
  String inString = port.readString().trim();
  
  // カンマで分割
  String[] values = split(inString, ',');
  
  if (values.length >= 4) {
    try {
      int ledNumber = Integer.parseInt(values[0].trim());
      int r = Integer.parseInt(values[1].trim());
      int g = Integer.parseInt(values[2].trim());
      int b = Integer.parseInt(values[3].trim());
      
      // LED番号の検証
      if (ledNumber >= 0 && ledNumber < NUM_LEDS) {
        // 0-255の範囲に制限
        r = constrain(r, 0, 255);
        g = constrain(g, 0, 255);
        b = constrain(b, 0, 255);
        
        // 配列に色情報を格納
        int colorIndex = ledNumber * 3;
        ledColors[colorIndex] = (byte)r;
        ledColors[colorIndex + 1] = (byte)g;
        ledColors[colorIndex + 2] = (byte)b;
        
        // デバッグ情報
        PVector pos = getLedPosition(ledNumber);
        println("LED " + ledNumber + " at position (" + pos.x + "," + pos.y + "," + pos.z + ") set to color (" + r + "," + g + "," + b + ")");
      } else {
        println("エラー: LED番号が範囲外です（0-" + (NUM_LEDS-1) + "）: " + ledNumber);
      }
    } catch (NumberFormatException e) {
      println("エラー: 数値の解析に失敗しました: " + inString);
      println(e);
    }
  } else {
    println("エラー: 無効なデータ形式です。[LED番号,R,G,B]の形式で送信してください。");
  }
}

// マウスドラッグでキューブを回転
void mouseDragged() {
  if (!isDragging) {
    prevMouseX = mouseX;
    prevMouseY = mouseY;
    isDragging = true;
  }
  
  float dx = mouseX - prevMouseX;
  float dy = mouseY - prevMouseY;
  
  // Y軸回転（左右ドラッグ）
  rotY += dx * 0.01;
  
  // X軸回転（上下ドラッグ）
  rotX += dy * 0.01;
  
  // 前の位置を更新
  prevMouseX = mouseX;
  prevMouseY = mouseY;
}

void mouseReleased() {
  isDragging = false;
}

// キーボード入力でテスト用のコマンド
void keyPressed() {
  if (key == 'c' || key == 'C') {
    // すべての LED をクリア
    for (int i = 0; i < ledColors.length; i++) {
      ledColors[i] = 0;
    }
    println("すべての LED をクリアしました");
  } else if (key == 'f' || key == 'F') {
    // すべての LED をランダムな色で点灯
    for (int i = 0; i < NUM_LEDS; i++) {
      int colorIndex = i * 3;
      ledColors[colorIndex] = (byte)int(random(256));
      ledColors[colorIndex + 1] = (byte)int(random(256));
      ledColors[colorIndex + 2] = (byte)int(random(256));
    }
    println("すべての LED をランダムな色で点灯しました");
  } else if (key == 'p' || key == 'P') {
    // パターンの表示（例：X-Y平面の対角線）
    for (int i = 0; i < ledColors.length; i++) {
      ledColors[i] = 0;
    }
    
    for (int i = 0; i < CUBE_SIZE; i++) {
      int ledIndex1 = getLedIndex(i, i, i);
      int colorIndex1 = ledIndex1 * 3;
      ledColors[colorIndex1] = (byte)255;     // R
      ledColors[colorIndex1 + 1] = (byte)0;   // G
      ledColors[colorIndex1 + 2] = (byte)0;   // B
      
      int ledIndex2 = getLedIndex(i, i, CUBE_SIZE-1-i);
      int colorIndex2 = ledIndex2 * 3;
      ledColors[colorIndex2] = (byte)0;       // R
      ledColors[colorIndex2 + 1] = (byte)255; // G
      ledColors[colorIndex2 + 2] = (byte)0;   // B
      
      int ledIndex3 = getLedIndex(i, CUBE_SIZE-1-i, i);
      int colorIndex3 = ledIndex3 * 3;
      ledColors[colorIndex3] = (byte)0;       // R
      ledColors[colorIndex3 + 1] = (byte)0;   // G
      ledColors[colorIndex3 + 2] = (byte)255; // B
      
      int ledIndex4 = getLedIndex(CUBE_SIZE-1-i, i, i);
      int colorIndex4 = ledIndex4 * 3;
      ledColors[colorIndex4] = (byte)255;     // R
      ledColors[colorIndex4 + 1] = (byte)255; // G
      ledColors[colorIndex4 + 2] = (byte)0;   // B
    }
    println("対角線パターンを表示しました");
  } else if (key == 'r' || key == 'R') {
    // 回転をリセット
    rotX = QUARTER_PI;
    rotY = QUARTER_PI;
    println("回転をリセットしました");
  }
}
