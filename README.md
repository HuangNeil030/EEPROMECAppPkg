# EEPROMECAppPkg

# EEPROM/EC Tool — README（使用筆記 / 函數使用方法）

本筆記對應 `EEPROMECTool_Annotated.c`，目的是幫你把「Port I/O / Index I/O」兩條路的觀念、流程、timeout 意義一次釐清。
EEPROM EC TOOL (EC EEPROM 讀寫工具)
│
├── UI / Console (使用者介面與終端機控制)
│   ├── Color             // 設定終端機字體與背景顏色
│   ├── PrH               // 格式化列印提示文字 (綠色括號)
│   └── Draw              // 負責渲染主畫面 (標題列、16x16 Hex 網格、ASCII 對照區、快捷鍵)
│
├── Wait Helpers (硬體等待與同步機制)
│   ├── PortWait          // 輪詢實體 I/O Port 狀態 (如 IBF/OBF)，具備 Timeout 超時保護
│   └── IdxWaitCtl        // 透過間接讀取 EC RAM，等待 Control Register 的特定旗標 (Processing/Start)
│
├── Low-Level Access (底層 Index I/O 間接存取層)
│   ├── IdxRead8          // 寫入 High/Low Index 位址後，從 Data Port 讀取 EC RAM 數值
│   └── IdxWrite8         // 寫入 High/Low Index 位址後，將數值寫入 Data Port
│
├── Protocol Handlers (硬體協定執行層)
│   ├── PortOp            // 執行標準 KBC/ACPI 的 Port I/O 讀寫命令交握序列 (60/64 或 62/66)
│   └── IdxExec           // 執行廠商 (ENE/Nuvoton) 特定的 Mailbox 交握 (鎖定 -> 填 Buffer -> 觸發 -> 等待)
│
├── High-Level API (高階應用 API 層)
│   ├── EcSetBank         // 封裝切換 EEPROM Bank 的邏輯 (根據當前 mAccType 自動導向 PortOp 或 IdxExec)
│   └── EcRW              // 封裝單一 Byte 的讀/寫邏輯 (自動處理讀回驗證與底層導向)
│
├── Data & Input (資料管理與使用者輸入)
│   ├── Refresh           // 觸發 Bank 切換，並連續讀取 256 Bytes 存入 mDump 軟體快取
│   └── InputHex          // 攔截鍵盤敲擊，過濾非 Hex 字元，並轉換為 UINT32 數值 (支援 Byte/Word/DWord)
│
└── Main Entry (主程式入口與事件迴圈)
    └── UefiMain          // 初始化變數與畫面，進入無窮迴圈攔截按鍵 (方向鍵、F1/F2、I、TAB、R、Enter、ESC)
---

## 1) 介面總覽

### A. Port I/O（兩組常見 port pair）
| 類型 | Data Port | Cmd/Status Port | 常見稱呼 | 備註 |
|---|---:|---:|---|---|
| 8042/KBC legacy | 0x60 | 0x64 | **60/64** | 很多平台此通道是鍵盤控制器(KBC)或 SMI handler，不一定把 0x42/0x4E/0x4D 轉給 EC。 |
| ACPI EC | 0x62 | 0x66 | **62/66** | 很多平台 EC 命令/資料是走這組，通常也比較「真的」可用。 |

**Port I/O 狀態 bit：**讀 *Cmd/Status Port*（0x64 或 0x66）
- **OBF (bit0)**：Output Buffer Full（可讀 data）
- **IBF (bit1)**：Input Buffer Full（不可再寫）

---

### B. Index I/O（ENE / Nuvoton / ITE）
Index I/O 本質：用 3 個 I/O port 間接存取 EC RAM（或 EC 的“命令通道 RAM window”）

**共通硬體行為：**
1. `IoWrite8(Base+H, AddrHi)`
2. `IoWrite8(Base+L, AddrLo)`
3. `IoRead8(Base+D)` or `IoWrite8(Base+D, Val)`

---

## 2) ITE Index I/O mapping（你給的表）

- `EC_INDEXIO_BASE = 0x0D00 (ITE)`
- EC RAM address（注意：這些是 **EC RAM 位址**，不是 I/O port）
  - `EC_INDEXIO_CMD_BUFFER              = 0xC62B`
  - `EC_INDEXIO_DATA_OF_CMD_BUFFER      = 0xC62C`
  - `EC_INDEXIO_CMD_WRITE_DATA_BUFFER   = 0xC62D`
  - `EC_INDEXIO_CMD_CNTL                = 0xC622`
  - `EC_INDEXIO_CMD_RETURN_DATA_BUFFER  = 0xC623`

**Index port offset：**
- `Base + 0x01` = index high byte
- `Base + 0x02` = index low byte
- `Base + 0x03` = data (read/write)

> 所以「讀 EC RAM 0xC622」不是 `IoRead8(0xC622)`，而是：
> - write (0x0D00+1)=0xC6
> - write (0x0D00+2)=0x22
> - read  (0x0D00+3)

---

## 3) EEPROM 命令流程（對應投影片）

### Set EEPROM Bank（Cmd=0x42）
- PortIO(62/66 or 60/64)
  1. Wait IBF=0
  2. Write CMD=0x42 to CmdPort
  3. Wait IBF=0
  4. Write Bank to DataPort

- IndexIO
  1. Wait Control.Processing(bit0)=0
  2. Set Processing=1
  3. Fill buffers：Cmd=0x42、BankBuf=bank
  4. Set Start=1（常見是寫 Ctl=0b11）
  5. Wait Start(bit1)=0
  6. Clear Processing=0

### Read EEPROM（Cmd=0x4E）
- PortIO
  1. CMD=0x4E
  2. Write Addr
  3. Wait OBF=1
  4. Read Data

- IndexIO
  1. Fill buffers：Cmd=0x4E、AddrBuf=addr
  2. Trigger Start
  3. Wait done
  4. Read ReturnBuf

### Write EEPROM（Cmd=0x4D）
- PortIO
  1. CMD=0x4D
  2. Write Addr
  3. Write Data

- IndexIO
  1. Fill buffers：Cmd=0x4D、WriteAddr=addr、WriteData=data（或依 mapping）
  2. Trigger Start
  3. Wait done

---

## 4) timeout 是什麼意思？（最重要）

### 你的程式中的 timeout = 「狀態 bit 一直沒有達到期待」
- PortIO timeout 常見發生在：
  - **Wait IBF=0**：IBF 一直是 1（EC/KBC 沒吃掉你寫入的 byte）
  - **Wait OBF=1**：OBF 一直是 0（EC 沒產生輸出資料、命令不支援、或走錯通道）

- IndexIO timeout 常見發生在：
  - **Wait Processing=0**：代表控制區卡在忙碌（或根本讀不到正確 control）
  - **Wait Start=0**：Start 一直不被清掉（EC 沒執行、介面沒連、或被鎖）

---

## 5) 為什麼 62/66 OK，但 60/64、FD60/0A00/0D00 都 timeout？

你描述「除了 62/66 以外的功能都 timeout」，最常見代表：

### (A) 60/64：不是你的 EC command channel
- 60/64 在很多平台是 **鍵盤控制器(KBC)** / **SMI trap**，不會把 `0x42/0x4E/0x4D` 當 EC EEPROM 命令處理。
- 你可能看到 IBF/OBF 會跳，因此“不太 timeout”，但讀回資料可能不對（例如固定值/全 0xFF）。
- 真要透過 60/64 對 EC 發命令，很多平台需要 **KBC Passthrough**（例如先寫 0xD4 到 0x64，再把 EC command/data 寫到 0x60），或平台根本不支援。

### (B) FD60/0A00/0D00：Index I/O 可能「沒開 / 沒解碼 / 被鎖」
- SIO/EC 的 index I/O base 需要 BIOS 設定啟用（LPC decode / base address enable）。
- 有的平台只在 SMM 或特定階段開放，UEFI Shell 下會被鎖住。
- mapping 位址表可能不同（Ctl/Cmd buffer address 不同）→ 你一直在讀錯位址，自然永遠等不到 bit 變化。
- 即便 base 正確，也可能需要先做 **unlock sequence** 或先把某個 enable bit 打開。

---

## 6) Debug 建議（你現在最需要做的事）

1. **在 timeout 時印出：**
   - PortIO：CmdPort status（IBF/OBF 全 bit）
   - IndexIO：Control byte（Ctl 地址 + 值）
2. **做 “活性測試”**：
   - IndexIO：連續讀同一個 EC RAM 位址（例如 Ctl），看是否讀值會變、是否永遠是 0xFF/0x00（像沒解碼）
3. **確認 address table**：
   - 用 BIOS/SIO 文件或 DSDT/EC driver 來源確認：
     - IndexIoBase 是否真的是 0xFD60/0A00/0D00
     - Ctl/Cmd buffer 是否真的是 0xF982/0x1282/0xC622
4. **如果 60/64 想要真的控 EC**：
   - 查平台是否需要 KBC passthrough（常見 0xD4 路徑），或根本不支援。

---

## 7) 函數使用快速索引

- `PortWait(port, mask, target)`：輪詢 port 的狀態 bit 到達 target
- `PortOp(cmd, val, isWrite)`：PortIO 下的一次 “set bank / read / write” 原語
- `IdxRead8(addr)` / `IdxWrite8(addr,val)`：IndexIO 的 indirect EC RAM 存取
- `IdxExec(cmd, addr, data)`：IndexIO 一次命令（含 wait/trigger/done）
- `EcSetBank(bank)`：統一 bank
- `EcRW(addr, &data, isWrite)`：統一 read/write

---

cd /d D:\BIOS\MyWorkSpace\edk2

edksetup.bat Rebuild

chcp 65001

set PYTHONUTF8=1

set PYTHONIOENCODING=utf-8

rmdir /s /q Build\EEPROMECAppPkg

build -p EEPROMECAppPkg\EEPROMECAppPkg.dsc -a X64 -t VS2019 -b DEBUG
