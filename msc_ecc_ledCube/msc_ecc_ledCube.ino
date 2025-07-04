#include "Adafruit_TinyUSB.h"
#include "jisc_ssd.h"

//USB StackをAdafruit_TinyUSBにしてください

#define BLOCK_NUM (6*6*6)

Adafruit_USBD_MSC usb_msc;
int target_block = -1;
bool haveBufferData = false;

void accessLed()
{
  static bool led = 0;
  digitalWrite(PIN_LED, led);
  if(led){
    led = 0;
  }else{
    led = 1;
  }
}

void setup() {
  pinMode(PIN_LED, OUTPUT);

  jisc_ssd_lowlevel_operation_init();
  jisc_ssd_lowlevel_operation_reset();

  usb_msc.setID("Afafruit","External Flash", "1.0");
  usb_msc.setReadWriteCallback(msc_read, msc_write, msc_flush);
  usb_msc.setCapacity(BLOCK_NUM*jisc_ssd_pages_of_block*2,512);//1 Block = 2LBA
  usb_msc.setUnitReady(true);
  usb_msc.begin();

  Serial1.setTX(28);  // TXをGP0に
  Serial1.setRX(29);  // RXをGP1に
  Serial1.begin(115200);
}

// バッファが全て0かどうかをチェックする関数
bool is_buffer_all_zeros(const uint8_t* buffer, size_t size) {
    // 高速化のため、32ビット単位でチェック
    const uint32_t* buf32 = (const uint32_t*)buffer;
    size_t words = size / 4;
    
    // 32ビット単位でチェック
    for (size_t i = 0; i < words; i++) {
        if (buf32[i] != 0) {
            return false;
        }
    }
 
    return true;
}

int32_t msc_read(uint32_t lba, void *buffer, uint32_t bufsize){
  accessLed();
  //LBA = Logical Block Address
  //ここではLBA = pageの1/4としている
  int page = bad_block_replace(lba/2);
  int in_page = page%jisc_ssd_pages_of_block;
  int block = page / jisc_ssd_pages_of_block;
#if 0
  Serial1.print("lba:");
  Serial1.print(lba);
  Serial1.print(" bufsize:");
  Serial1.print(bufsize);
  Serial1.println();
  Serial1.print("target_block:");
  Serial1.print(target_block);
  Serial1.print(" block:");
  Serial1.print(block);
  Serial1.print(" page:");
  Serial1.print(page);
  Serial1.print(" in_page:");
  Serial1.print(in_page);
  Serial1.println();
#endif
  if(target_block != block){
    if(target_block >= 0 && haveBufferData){
      //現在保持しているブロックの内容を書き込み
      if(jisc_ssd_block_buffer[jisc_ssd_block_size-1] != 0xFF){
        eraseBlockOp(target_block);
      }
      jisc_ssd_block_buffer[jisc_ssd_block_size-1] = 0xAA; //使用済みブロックマーキング
      writeBlockOp(target_block);
    }

    target_block = block;
    haveBufferData = false;

    //クリア
    //memset(jisc_ssd_block_buffer,0xFF,jisc_ssd_block_size);

    //ブロック読み出し
    readBlockOp(block);
  }
  memcpy(buffer, &(jisc_ssd_block_buffer[(jisc_ssd_page_size * in_page) + (512*(lba%2))]), bufsize);
  return bufsize;
}

int32_t msc_write(uint32_t lba, uint8_t *buffer, uint32_t bufsize){

  accessLed();
  int page = bad_block_replace(lba/2);
  int in_page = page % jisc_ssd_pages_of_block;
  int block = page / jisc_ssd_pages_of_block;
#if 0
  Serial1.print("lba:");
  Serial1.print(lba);
  Serial1.print(" bufsize:");
  Serial1.print(bufsize);
  Serial1.println();
  Serial1.print("target_block:");
  Serial1.print(target_block);
  Serial1.print(" block:");
  Serial1.print(block);
  Serial1.print(" page:");
  Serial1.print(page);
  Serial1.print(" in_page:");
  Serial1.print(in_page);
  Serial1.println();
#endif
  if(target_block != block){
    if(target_block >= 0 && haveBufferData){
      //現在保持しているブロックの内容を書き込み
      if(jisc_ssd_block_buffer[jisc_ssd_block_size-1] != 0xFF){
        eraseBlockOp(target_block);
      }
      jisc_ssd_block_buffer[jisc_ssd_block_size-1] = 0xAA; //使用済みブロックマーキング
      writeBlockOp(target_block);
    }

    target_block = block;
    haveBufferData = false;

    //クリア
    //memset(jisc_ssd_block_buffer,0xFF,jisc_ssd_block_size);

    //ブロック読み出し
    readBlockOp(block);
  }
  memcpy(&(jisc_ssd_block_buffer[(jisc_ssd_page_size * in_page) + (512*(lba%2))]), buffer, bufsize);
  haveBufferData = true;
  return bufsize;
}

void msc_flush()
{
    if(target_block >= 0){
      //現在保持しているブロックの内容を書き込み
      if(jisc_ssd_block_buffer[jisc_ssd_block_size-1] != 0xFF){
        eraseBlockOp(target_block);
      }
      jisc_ssd_block_buffer[jisc_ssd_block_size-1] = 0xAA; //使用済みブロックマーキング
      writeBlockOp(target_block);

      haveBufferData = false;
    }

    target_block = -1;
}

int bad_block_replace(int page){
#if 0
  int block = page / jisc_ssd_pages_of_block;
  switch(block){
    case 93:
      page = page + ((-93 + BLOCK_NUM) * jisc_ssd_pages_of_block);
      break;
    case 768:
      page = page + ((-768 + 1001) * jisc_ssd_pages_of_block);
      break;
    default:
      break;
  }
#endif
  return page;
}


void loop() {
  return;
}

bool checkErrorStatus(){
  jisc_ssd_lowlevel_operation_command_input(0x70);
  int x1 = jisc_ssd_lowlevel_operation_serial_data_output();
  if ((x1 & 1) != 0) {
    return true;
  }
  return false;
}

void writeBlockOp(int block){

  if(is_buffer_all_zeros(jisc_ssd_block_buffer, 512))
  {
    Serial1.printf("%d, 0, 0, 255\n",block);
  }
  else
  {
    Serial1.printf("%d, 255, 0, 0\n",block);
  }
  
  int offset = jisc_ssd_pages_of_block * block;
  for(int i=0;i<jisc_ssd_pages_of_block-1;i++)
  {
    int page_addr = i + offset;
    jisc_ssd_lowlevel_operation_command_input(0x80);
    jisc_ssd_lowlevel_operation_address4_input(0x00, 0x00, page_addr & 0xFF, ((page_addr >> 8) & 0xFF));

    jisc_ssd_lowlevel_operation_data_input_page_from_block_buffer(
      &(jisc_ssd_block_buffer[jisc_ssd_page_size * i])
    );
    jisc_ssd_lowlevel_operation_command_input(0x15);
  }

  {
    int i = jisc_ssd_pages_of_block-1;
    int page_addr = i + offset;
    jisc_ssd_lowlevel_operation_command_input(0x80);
    jisc_ssd_lowlevel_operation_address4_input(0x00, 0x00, page_addr & 0xFF, ((page_addr >> 8) & 0xFF));

    jisc_ssd_lowlevel_operation_data_input_page_from_block_buffer(
      &(jisc_ssd_block_buffer[jisc_ssd_page_size * i])
    );
    jisc_ssd_lowlevel_operation_command_input(0x10);
  }

  if(checkErrorStatus()){
    Serial1.println("Error! ABORT");
    return;
  }
}

void readBlockOp(int block){

  Serial1.printf("%d, 0, 255, 0\n",block);

  int offset = jisc_ssd_pages_of_block * block;
  for(int i=0;i<jisc_ssd_pages_of_block;i++)
  {
    int page_addr = i + offset;
    jisc_ssd_lowlevel_operation_command_input(0x00);

    //カラムアドレスはページ内オフセットと思えば良い
    jisc_ssd_lowlevel_operation_address4_input(0x00, 0x00, page_addr & 0xFF, ((page_addr >> 8) & 0xFF));
    jisc_ssd_lowlevel_operation_command_input(0x30);
    jisc_ssd_lowlevel_operation_serial_data_output_page_to_block_buffer(
      &(jisc_ssd_block_buffer[jisc_ssd_page_size * i])
    );
  }
}

void eraseBlockOp(int block)
{
  Serial1.printf("%d, 255, 255, 255\n", block);
  int page = block * jisc_ssd_pages_of_block;
  jisc_ssd_lowlevel_operation_command_input(0x60);
  jisc_ssd_lowlevel_operation_address2_input(page & 0xFF, ((page >> 8) & 0xFF)); //下位6bitに意味はない？
  jisc_ssd_lowlevel_operation_command_input(0xD0);
  sleep_ms(100);
}
