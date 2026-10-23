# Monitoring Kit  (Grafana + Prometheus + Loki + Alloy)

`scripts/up` script တစ်ကြောင်းတည်းနဲ့ (အတွင်းမှာ `docker compose up -d` ကို ခေါ်ပေးတယ်) အောက်ပါအရာအားလုံး **အသင့်သတ်မှတ်ပြီးသား** စတင်ပေးတဲ့ ပက်ကေ့ချ်ပါ။

- ✅ စက်ရဲ့ CPU / RAM / Disk / Network ကို ဂရပ်နဲ့ ကြည့်ရ (Dashboard အသင့်ပါ)
- ✅ App ရဲ့ log တွေကို စုပြီး ရှာလို့ရ (Dashboard အသင့်ပါ)
- ✅ ပြဿနာဖြစ်ရင် **Email နဲ့ အလိုအလျောက် သတိပေး** (Alert rule ၅ ခု အသင့်ပါ)
- ✅ Data source ချိတ်ခြင်း၊ Dashboard တင်ခြင်း၊ Alert ထည့်ခြင်းတွေကို ကိုယ်တိုင် လုပ်စရာမလို

---

## ၁။ အစိတ်အပိုင်းတစ်ခုချင်းစီ ဘာလို့ သုံးလဲ

ဥပမာတစ်ခု : **ဆေးခန်းတစ်ခု** လို့ စဉ်းစားကြည့်ပါ။ App/Server ဆိုတာ လူနာ၊ Monitoring ဆိုတာ လူနာရဲ့ အခြေအနေကို စောင့်ကြည့်တဲ့ စက်ကိရိယာတွေပါ။

| အစိတ်အပိုင်း | အလုပ် | ဥပမာနဲ့ ရှင်းရင် |
|---|---|---|
| **windows_exporter** | Windows စက်ရဲ့ CPU/RAM/Disk/Network ကိန်းဂဏန်းတွေကို ထုတ်ပေးတဲ့ program | လူနာရဲ့ **သွေးခုန်နှုန်း၊ ဖိအား တိုင်းတဲ့ ကိရိယာ** |
| **Prometheus** | အဲဒီကိန်းဂဏန်းတွေကို ၁၅ စက္ကန့်တစ်ခါ သွားယူပြီး အချိန်နဲ့အမျှ မှတ်တမ်းတင်သိမ်းတဲ့ database | **နာရီတိုင်း မှတ်တမ်းရေးတဲ့ သူနာပြု** |
| **Alloy** | App ရဲ့ log ဖိုင်ကို ဖတ်ပြီး Loki ဆီ ပို့တဲ့ စုဆောင်းသူ | **မှတ်စုတွေကို စုပြီး မှတ်တမ်းခန်းကို ပို့တဲ့ ပို့ဆောင်သူ** |
| **Loki** | Log (စာကြောင်းတွေ) ကို သိမ်းပြီး ရှာလို့ရတဲ့ database | **မှတ်တမ်းခန်း (ဖိုင်ဗီရို)** |
| **Grafana** | အပေါ်က ဒေတာအားလုံးကို ပုံ/ဂရပ်နဲ့ ပြတဲ့ မျက်နှာပြင်၊ Alert email ပို့တဲ့ နေရာလည်း ဖြစ်တယ် | **ဆရာဝန်ရဲ့ မော်နီတာ မျက်နှာပြင်နဲ့ သတိပေးဘဲလ်** |

### ဘာကြောင့် Prometheus ရော Loki ရော နှစ်ခုလုံး လိုလဲ?

- **Prometheus = ကိန်းဂဏန်း** ("CPU ဘယ်လောက်ရာခိုင်နှုန်း?") ကို သိမ်းတာ
- **Loki = စာသား log** ("ဘာ error ပေါ်သွားလဲ၊ ဘာကြောင့်လဲ?") ကို သိမ်းတာ
- ကိန်းဂဏန်းက **"တစ်ခုခုမှားနေတယ်"** ဆိုတာကို သိစေပြီး၊ log က **"ဘာကြောင့်မှားလဲ"** ဆိုတာကို ပြောပြတယ်။ ဒါကြောင့် နှစ်ခုလုံး လိုပါတယ်။

### Alloy ကို ဘာလို့ သီးခြားသုံးလဲ?

App က log ကို ဖိုင်ထဲ ရေးတာပဲ ရှိတယ်။ အဲဒီဖိုင်ကို ဖတ်ပြီး Loki ဆီ ပို့ပေးဖို့ ကြားခံ တစ်ခု လိုတယ်။ Alloy က
(၁) ဖိုင်ဘယ်အထိ ဖတ်ပြီးပြီလဲ မှတ်ထားလို့ restart လုပ်ရင် ပြန်မထပ်ဖတ်ဘူး၊
(၂) log ကို `INFO / WARN / ERROR` label ခွဲပေးတယ်၊
(၃) ဟောင်းသွားတဲ့ (`.gz`) ဖိုင်တွေကို မဖတ်ဘူး။

---

## ၂။ ဖွဲ့စည်းပုံ

```
 [ကိုယ့် App]                          [ကိုယ့် Windows/Linux စက်]
   │ log ကို ဖိုင်ထဲရေး                      │ windows_exporter / node_exporter
   ▼                                         ▼
 logs/*.log ──► Alloy ──► Loki           Prometheus
                           │                 │
                           └───► Grafana ◄───┘
                                    │
                             ကြည့်ရတဲ့ မျက်နှာပြင် + Email alert
```

```
monitoring-kit/
├─ compose.yaml                  ← Container ၄ ခုကို စတင်တဲ့ အဓိကဖိုင်
├─ .env.example  →  .env         ← ကိုယ့်ရဲ့ setting (PLATFORM, password, email, folder) ဖြည့်ရတဲ့ဖိုင်
├─ prometheus/
│   ├─ prometheus.windows.yml    ← PLATFORM=windows ဆိုရင် သုံး (windows_exporter :9182)
│   └─ prometheus.linux.yml      ← PLATFORM=linux ဆိုရင် သုံး (node_exporter :9100)
├─ loki/loki.yaml                ← Log သိမ်းပုံ (၃၀ ရက်)
├─ alloy/config.alloy            ← ဘယ် log ဖိုင်ကို ဖတ်ပြီး ဘယ်လို label တပ်မလဲ
├─ grafana/
│   ├─ provisioning/datasources/ ← Grafana ကို Prometheus/Loki နဲ့ အလိုအလျောက် ချိတ်
│   ├─ provisioning/dashboards/  ← Dashboard ဖိုင်တွေကို အလိုအလျောက် ဖွင့်
│   ├─ alerting/common/          ← Email လိပ်စာ၊ ပို့ပုံ (နှစ်မျိုးလုံး တူ)
│   ├─ alerting/windows/rules.yaml  ← Windows အတွက် Alert rule ၅ ခု
│   ├─ alerting/linux/rules.yaml    ← Linux အတွက် Alert rule ၅ ခု
│   └─ dashboards/
│       ├─ common/app-logs.json     ← App log Dashboard (နှစ်မျိုးလုံး)
│       ├─ windows/windows-host.json
│       └─ linux/linux-host.json
├─ features/app-metrics/         ← DTM App Metrics (Prometheus job, Dashboard, Alert ၄ ခု) - APP_METRICS_ENABLE=true ဆိုမှ တင်မယ်
├─ logs/                         ← (မူရင်း) App ရဲ့ log ဖိုင် ထည့်ရမယ့်နေရာ
└─ scripts/
    ├─ Windows:  up.ps1 · install-windows-exporter.ps1 · check.ps1 · send-test-error.ps1 · test-telegram.ps1
    └─ Linux:    up.sh · install-node-exporter.sh · check.sh · send-test-error.sh · test-telegram.sh

(`.generated/` folder ကို `up` script က အလိုအလျောက် ဖန်တီးတယ်၊ ကိုယ်တိုင် မပြင်ပါနဲ့၊ Git ထဲလည်း မတင်ပါနဲ့။)
```

**Windows နဲ့ Linux ကို `.env` ထဲက `PLATFORM=windows` / `PLATFORM=linux` တစ်ကြောင်းနဲ့ ရွေးတယ်။** ရွေးလိုက်တဲ့ဘက်ရဲ့ Prometheus config၊ Alert rule၊ Host Dashboard ကိုပဲ တင်ပေးတယ်။ ကျန်တဲ့ဘက်ဖိုင်တွေကို မထိပါ။

---

## ၃။ စတင်အသုံးပြုနည်း (Windows)

> Linux server ဆိုရင် [အပိုင်း ၈](#၈-linux-staging--production-မှာ-သုံးရင်) ကို သွားပါ။ ကျန်အပိုင်းတွေ (၄ - ၇) က နှစ်မျိုးလုံး တူပါတယ်။

### လိုအပ်တာ

- **Docker Desktop** (Linux containers mode၊ ဖွင့်ထားပြီး "Engine running" ဖြစ်နေရမယ်)
- Gmail အကောင့်တစ်ခု နဲ့ **App Password** (https://myaccount.google.com/apppasswords ၊ 2-Step Verification ဖွင့်ထားရမယ်)

### အဆင့် ၁ — Setting ဖြည့်

ဒီ kit folder ထဲမှာ PowerShell ဖွင့်ပါ။

```powershell
Copy-Item .env.example .env
notepad .env
```

အနည်းဆုံး ဒီ ၅ ခုကို ဖြည့်ပါ (**quote မထည့်ပါနဲ့၊ space မထားပါနဲ့**)။

| ကွက် | ဘာထည့်မလဲ |
|---|---|
| `GRAFANA_ADMIN_PASSWORD` | Grafana ဝင်ဖို့ ကိုယ်ပိုင် password (အရှည်ကြီး) |
| `ALERT_EMAIL` | Alert လက်ခံမယ့် email |
| `SMTP_USER` | ပို့မယ့် Gmail လိပ်စာ |
| `SMTP_PASSWORD` | Gmail **App Password** (၁၆ လုံး၊ space မပါ) |
| `SMTP_FROM` | `SMTP_USER` နဲ့ တူတူ |

`PLATFORM=windows` ဖြစ်နေကြောင်း စစ်ပါ။ ကျန်တာတွေ (`MONITORING_ENV`, `MONITORING_HOST`, `LOG_DIR`) ကို ကိုယ့်စက်နဲ့ ကိုက်အောင် ပြင်ပါ။ `MONITORING_HOST` က `prometheus/prometheus.windows.yml` ထဲက `host:` နဲ့ တူရင် ပိုကောင်းတယ်။

### အဆင့် ၂ — windows_exporter install (Windows ပဲ၊ တစ်ခါပဲ လုပ်ရ)

**Administrator PowerShell** မှာ (Start → PowerShell ကို right-click → Run as administrator):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-windows-exporter.ps1
```

ပြီးရင် http://localhost:9182/metrics ကို browser မှာ ဖွင့်ကြည့်ပါ၊ စာတွေ အများကြီးပေါ်ရင် အောင်ပြီ။

### အဆင့် ၃ — စတင်

```powershell
powershell -ExecutionPolicy Bypass -File scripts\up.ps1
```

`docker compose up -d` ကို တိုက်ရိုက်မခေါ်ပါနဲ့။ `up` script က `.env` ထဲက ဖွင့်/ပိတ် setting (အပိုင်း ၅ ကိုကြည့်) အတိုင်း ဖိုင်တွေ ထုတ်ပေးပြီးမှ Docker ကို စတင်တာပါ။

ပထမဆုံးအကြိမ်ဆို image တွေ download လုပ်လို့ ၂-၅ မိနစ်ကြာနိုင်ပါတယ်။

### အဆင့် ၄ — စစ်

၃၀ စက္ကန့်လောက်စောင့်ပြီး:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

`ALL CHECKS PASSED` ပေါ်ရင် ပြီးပါပြီ။ ပြီးရင် http://127.0.0.1:3000 ကို ဖွင့်ပြီး `admin` နဲ့ `.env` ထဲက password နဲ့ ဝင်ပါ။ ဘယ်ဘက် menu **Dashboards** → **Monitoring** folder ထဲမှာ Dashboard ၂ ခု ရှိပါတယ်။

---

## ၄။ ကိုယ့် App ကို ချိတ်ပုံ (Log စုဖို့)

Alloy က `LOG_DIR` folder ထဲက **`*.log`** ဖိုင်အားလုံးကို ဖတ်ပါတယ်။ **ဖိုင်နာမည်က `service` label ဖြစ်သွားပါတယ်။**

- `e-services.log` → `service="e-services"`
- `shop-api.log` → `service="shop-api"`

ဒါကြောင့် app တစ်ခုချင်းစီကို ကိုယ်ပိုင်ဖိုင်နာမည်ပေးပါ။

### Spring Boot app ဆိုရင် (Environment variable ၂ ခုပဲ — code မပြင်ရ)

```
LOGGING_FILE_NAME=D:/path/to/monitoring-kit/logs/my-app.log
LOGGING_STRUCTURED_FORMAT_FILE=ecs
```

`ecs` ဆိုတာ log ကို JSON ပုံစံနဲ့ ရေးခိုင်းတာ။ ဒီမှာ `log.level` ပါလို့ Alloy က `INFO/WARN/ERROR` ကို ခွဲထုတ်နိုင်တယ်။ (IntelliJ → Run configuration → Environment variables ထဲ ထည့်ပါ၊ ပြီးရင် app ကို restart လုပ်ပါ။)

### တခြား app (Node, Python, ...)

- Log ကို ဖိုင်ထဲ **JSON တစ်ကြောင်း တစ်ခု** ပုံစံနဲ့ ရေးပြီး `"log.level":"ERROR"` ဆိုတဲ့ field ထည့်ပါ။
- JSON မဟုတ်ရင်လည်း log ကို သိမ်းပါတယ်၊ ဒါပေမယ့် `level` label မရပါဘူး (ဒါကြောင့် `level="ERROR"` နဲ့ ရှာတာ/alert ပေးတာ မရပါ)။ အဲဒီအခါ `alloy/config.alloy` ကို ပြင်ရပါမယ်။

### Log ကြည့်ရန်

Grafana → **Dashboards → Monitoring → Application Logs**။ ကိုယ်တိုင်ရှာချင်ရင် **Explore** → **Loki** → **Code** ကို ရွေးပြီး:

| ရှာချင်တာ | Query |
|---|---|
| Log အားလုံး | `{service=~".+"}` |
| ERROR ပဲ | `{level="ERROR"}` |
| WARN နဲ့ ERROR | `{level=~"WARN\|ERROR"}` |
| App တစ်ခုတည်း | `{service="e-services"}` |
| စာလုံးတစ်ခု ပါတာ | `{service="e-services"} \|= "payment"` |

---

## ၅။ Alert (Email သတိပေး) ၅ ခု

| Rule | ဘယ်အချိန် ပို့မလဲ |
|---|---|
| **Backend ERROR logs** | နောက်ဆုံး ၅ မိနစ်အတွင်း `ERROR` log တစ်ကြောင်းမဆို ပေါ်ရင် |
| **Host exporter down** | windows_exporter ကို ၂ မိနစ်ကျော် ချိတ်မရရင် |
| **Disk usage above 90%** | Drive (C:, D:, ...) တစ်ခု ၉၀% ကျော်ပြီး ၅ မိနစ်ကြာရင် |
| **Memory usage above 90%** | RAM ၉၀% ကျော်ပြီး ၅ မိနစ်ကြာရင် |
| **CPU usage above 90%** | CPU ၉၀% ကျော်ပြီး ၅ မိနစ်ကြာရင် |

- ပြဿနာ ပြေလည်သွားရင် `[RESOLVED]` email ထပ်ပို့တယ်။ မပြေလည်သေးရင် ၄ နာရီတစ်ခါ ပြန်သတိပေးတယ်။
- ပြင်ချင်ရင် (ဥပမာ ၉၀ ကို ၈၀ လုပ်) `grafana/alerting/<windows|linux>/rules.yaml` ကို ပြင်ပြီး `docker compose restart grafana`။
- ဒီ rule တွေက ဖိုင်ကလာတာမို့ Grafana UI ထဲမှာ ပြင်လို့မရပါဘူး (ဖိုင်ကနေပဲ ပြင်ရ)။
- Email လက်ခံသူကို ပြောင်းချင်ရင် `.env` ထဲက `ALERT_EMAIL` ကို ပြင်ပြီး `up` script ပြန် run ပါ။

### Alert လမ်းကြောင်း ဖွင့်/ပိတ်

`.env` ထဲမှာ `EMAIL_ALERT_ENABLE=true` (မရေးထားရင်လည်း `true` ပဲ)။ `false` လို့ပြောင်းပြီး `up` script ပြန် run ရင် email contact point မတင်တော့ဘူး၊ `ALERT_EMAIL`/`SMTP_*` ဖြည့်စရာလည်း မလိုတော့ဘူး။ Alert rule တွေကတော့ ဆက်အလုပ်လုပ်ပြီး Grafana မျက်နှာပြင်မှာ မြင်ရတယ်၊ ဘယ်ကိုမှ မပို့ဘူး။ 
### Telegram ထည့်ရန်

`TELEGRAM_ALERT_ENABLE=true` ဆိုရင် Alert ကို Telegram ကိုပါ ပို့မယ် (Email ပိတ်မထားရင် နှစ်ခုလုံးပို့)။ ဖွင့်ဖို့ အဆင့်တွေက:

1. Telegram မှာ **@BotFather** ကို ရှာပြီး `/newbot` ပို့ပါ။ နာမည်ပေးရင် **token** (`123456789:AAxxxx...`) ရမယ်။
2. ကိုယ့် bot ကို စာတစ်ကြောင်း ပို့ပါ (Group ထဲပို့ချင်ရင် bot ကို group ထဲထည့်ပြီး group ထဲမှာ စာရေးပါ)။
3. `.env` ထဲမှာ `TELEGRAM_BOT_TOKEN=` ကို ဖြည့်ပြီး ဒါကို run ပါ (`TELEGRAM_CHAT_ID` မဖြည့်ရသေးလည်း ရတယ်)။

```powershell
powershell -ExecutionPolicy Bypass -File scripts\test-telegram.ps1      # Linux: bash scripts/test-telegram.sh
```

4. `chat id: 123456789` လို့ ပြပေးမယ်။ အဲဒီနံပါတ် (group ဆိုရင် `-100...` လို အနှုတ်ပါ) ကို `TELEGRAM_CHAT_ID=` မှာ ဖြည့်ပါ။ ပြီးရင် script ကို ထပ် run ရင် "test message sent" ပြပြီး Telegram မှာ စာရောက်ရမယ်။
5. `.env` မှာ `TELEGRAM_ALERT_ENABLE=true` လုပ်ပြီး `up` script ပြန် run ပါ။ `send-test-error` နဲ့ alert စမ်းလို့ရတယ်။

Token ကို Git/chat/screenshot ထဲ မပို့ပါနဲ့။ ပေါက်ကြားရင် @BotFather မှာ `/revoke` လုပ်ပါ။

### Alert email အလုပ်လုပ်လား စမ်းရန်

```powershell
powershell -ExecutionPolicy Bypass -File scripts\send-test-error.ps1
```

၁-၂ မိနစ်အတွင်း `[FIRING:1] Backend ERROR logs` email ရောက်ရမယ်၊ ၅ မိနစ်ကျော်ရင် `[RESOLVED]` ထပ်လာမယ်။ (စမ်းတဲ့ log ဖိုင်ကို `logs\alert-test.log` မှာ ရေးတာမို့ ကိုယ့် app ကို မထိပါဘူး။)

---

## ၅.၁။ DTM App Metrics (Spring Boot) ဖွင့်ရန်

CPU/RAM ကိုပဲ မဟုတ်ဘဲ **backend ကိုယ်တိုင်ရဲ့** request အရေအတွက်၊ တုံ့ပြန်မှုနှေးမြန်၊ 5xx error၊ JVM heap၊ DB connection pool ကို Dashboard (`DTM App Metrics`) နဲ့ Alert ၄ ခုနဲ့ ကြည့်ရမယ်။

**Alert ၄ ခု:** `DTM app metrics down` (၂ မိနစ်ချိတ်မရ)၊ `DTM app 5xx errors` (၅ မိနစ်မှာ ၂ ကြိမ်ထက်ပို)၊ `DTM DB connection pool high` (၉၀% ကျော် ၅ မိနစ်)၊ `DTM JVM heap high` (၉၀% ကျော် ၁၀ မိနစ်)။ Dev မှာ backend ကို ပိတ်ထားရင် `app metrics down` က Firing ဖြစ်တာ ပုံမှန်ပါ။

**အဆင့် ၁ — Backend မှာ dependency ထည့် (`e-services-app/pom.xml`)**

`<dependencies>` ထဲမှာ ထည့်ပါ။ (`spring-boot-starter-actuator` က `admin-core` ကနေ ပါပြီးသား၊ version ကို Spring Boot က စီမံတယ်)

```xml
<dependency>
  <groupId>io.micrometer</groupId>
  <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

**အဆင့် ၂ — Dev မှာ `/actuator/prometheus` ကို login မလိုအောင် ဖွင့် (`application-dev.yaml`)**

`admin-core` ရဲ့ security က `/actuator/health`, `/actuator/info` ကိုပဲ login မလို ဖွင့်ထားတယ်။ ကျန်တာ JWT လိုတယ်၊ Prometheus က JWT မသုံးနိုင်ဘူး။ `admin.security.permitUrls` ကို dev မှာ ဒီလိုထပ်ရေးပါ (List က အစားထိုးတာမို့ `application.yaml` ထဲက ရှိပြီးသားအကုန်ကိုပါ ပြန်ထည့်ရမယ်၊ နောက်ကို `application.yaml` မှာ permitUrls ထပ်တိုးရင် dev မှာလည်း ထပ်ထည့်ဖို့မမေ့ပါနဲ့)။

```yaml
admin:
  security:
    permitUrls:
      - "/api/v1/application-charges/**"
      - "/api/v1/register/**"
      - "/api/v1/application-types/**"
      - "/api/v1/medicine-categories/**"
      - "/api/v1/medicine-packaging-styles/**"
      - "/api/v1/medicine-shapes/**"
      - "/api/v1/files/upload"
      - "/actuator/prometheus"
```
(`application-dev.yaml` မှာ `management.endpoints.web.exposure.include: "*"` ရှိပြီးသားမို့ endpoint ကို ထပ်ဖွင့်စရာ မလို)

**အဆင့် ၃ — Backend ကို `dev` profile နဲ့ restart လုပ်ပြီး စစ်**

Browser မှာ http://localhost:8080/actuator/prometheus ဖွင့်ပါ။ `# HELP ...` နဲ့ စာတွေ အများကြီးပေါ်ရင် အောင်ပြီ။ `401/403` ဆိုရင် အဆင့် ၂ မမှန်သေး၊ `404` ဆိုရင် အဆင့် ၁ (dependency) မရောက်သေး။

**အဆင့် ၄ — Kit မှာ ဖွင့်**

`.env` ထဲမှာ `APP_METRICS_ENABLE=true` လုပ်ပြီး `scripts\up.ps1` ပြန် run ပါ။ Prometheus နဲ့ Grafana ကို အလိုအလျောက် restart လုပ်ပေးတယ်။ ၁ မိနစ်လောက်နေရင် `check.ps1` မှာ `Prometheus target UP: dtm-app ...` ပေါ်ပြီး Grafana ရဲ့ Monitoring folder မှာ `DTM App Metrics` Dashboard ပေါ်လာမယ်။ Target က DOWN ဖြစ်နေရင် Windows Firewall က Docker ကနေ port 8080 ကို ပိတ်ထားတာ မကြာခဏ ဖြစ်တယ်။

**Staging / Production အတွက် သတိပေး:** အဆင့် ၂ ကို prod မှာ မလုပ်ပါနဲ့။ `/actuator/prometheus` ကို Internet ကနေ login မလိုဘဲ မြင်ရတော့မယ်။ Prod အတွက် သီးခြား management port (အတွင်းပိုင်း network ပဲ) နဲ့ လုပ်ဖို့ နောက်မှ သီးသန့်စီစဉ်ရမယ်။

**တိကျစေချင်တာ:** Dashboard/Alert query တွေက Spring Boot/Micrometer ရဲ့ ပုံမှန် metric နာမည် (`http_server_requests_seconds_*`, `jvm_memory_*`, `hikaricp_*`) နဲ့ ရေးထားတယ်။ Mock app နဲ့ Prometheus အစစ်မှာ query ပြေလည်ကြောင်း စမ်းထားပေမယ့် သင့် backend အစစ်နဲ့ မစမ်းရသေးပါ။ Panel တစ်ခုခု "No data" ဖြစ်ရင် `/actuator/prometheus` ထဲမှာ အဲဒီ metric နာမည် ရှိမရှိ ကြည့်ပါ။ Hikari panel တွေက DB pool metric ပေါ်မှ ပေါ်မယ်။

---

## ၅.၁.၁။ Staging / Production မှာ App Metrics ကို လုံခြုံအောင် ဖွင့်ရန်

Dev မှာ `/actuator/prometheus` ကို login မလိုအောင် ဖွင့်ထားတာ (permitUrls) ကို **Prod မှာ အပြင်လူတိုင်း မြင်နိုင်အောင် မထားရဘူး**။
Metrics ထဲမှာ endpoint နာမည်၊ DB pool၊ JVM အချက်အလက်တွေ ပါလို့ တိုက်ခိုက်သူအတွက် အချက်အလက်ပေးသလို ဖြစ်တယ်။
နည်း ၂ မျိုး (code ပြင်စရာမလို၊ config ပဲ) — ကိုယ့်အခြေအနေနဲ့ ကိုက်တာ ရွေးပါ။

**နည်း A — Kit နဲ့ backend က server တစ်ခုတည်း / private network တစ်ခုတည်းမှာ (အလွယ်ဆုံး)**

၁။ Staging/Prod ရဲ့ `application-stag.yaml` / `application-prod.yaml` မှာပဲ `admin.security.permitUrls` ထဲ `"/actuator/prometheus"` ထည့် (dev မှာ ထည့်ထားသလို)။
၂။ Backend port (8080) ကို **အပြင်ကို မဖွင့်ပါနဲ့** — nginx (localhost) နဲ့ monitoring kit ကပဲ ချိတ်နိုင်အောင် firewall ပိတ်။ Docker နဲ့ publish ထားရင် `127.0.0.1:8080:8080` လို့ bind ပါ (Docker က ufw ကို ကျော်တတ်လို့ ufw တစ်ခုတည်းကို မယုံပါနဲ့)။
၃။ Nginx မှာ `/actuator/` ကို အပြင်ကို မပေးပါနဲ့:

```
location /actuator/ { return 404; }
```

၄။ `.env` (kit ကို Linux server ပေါ်မှာ run၊ `PLATFORM=linux`):

```
APP_METRICS_ENABLE=true
APP_METRICS_TARGET=host.docker.internal:8080
```

Linux မှာ `host.docker.internal` က Docker bridge IP ကို ညွှန်းတယ်၊ ဒါကြောင့် backend က `0.0.0.0` မှာ listen လုပ်ရမယ် (127.0.0.1 တစ်ခုတည်း မရဘူး) နဲ့ firewall က Docker network ကနေ 8080 ကို ခွင့်ပေးရမယ်။ မဖြစ်ရင် `docker compose exec prometheus wget -qO- http://host.docker.internal:8080/actuator/prometheus | head` နဲ့ စစ်ပါ။

**နည်း B — Kit က တခြား server/internet ကနေ ချိတ်ရင် (nginx + HTTPS + password)**

Backend server ရဲ့ nginx မှာ metrics အတွက် သီးသန့် path တစ်ခု password နဲ့ ဖွင့်:

```
location = /metrics {
    auth_basic "metrics";
    auth_basic_user_file /etc/nginx/.metrics_htpasswd;
    proxy_pass http://127.0.0.1:8080/actuator/prometheus;
}
location /actuator/ { return 404; }
```

Password ဖိုင်ဆောက်: `sudo htpasswd -c /etc/nginx/.metrics_htpasswd prom` (apache2-utils လိုတယ်)။ Backend ရဲ့ 8080 က localhost ကိုပဲ listen/firewall လုပ်ထားရမယ် (permitUrls ထည့်ရမယ်၊ ဒါပေမယ့် nginx ကပဲ ချိတ်နိုင်လို့ ဘေးကင်းတယ်)။ ဒီ server က HTTPS (certificate) ရှိရမယ် — မရှိရင် password က ဖွင့်ပြီး ပို့တာဖြစ်သွားမယ်။

Kit ရဲ့ `.env`:

```
APP_METRICS_ENABLE=true
APP_METRICS_SCHEME=https
APP_METRICS_TARGET=api.ကိုယ့်domain:443
APP_METRICS_PATH=/metrics
APP_METRICS_USER=prom
APP_METRICS_PASSWORD=ကိုယ့်password
```

`scripts/up` က user/password ကို Prometheus config ထဲ basic_auth အဖြစ် ထည့်ပေးတယ် (`.generated/` ထဲမှာပဲ ရှိ၊ git ထဲ မတင်ပါနဲ့ — `.gitignore` မှာ ပါပြီးသား)။

**စစ်ပုံ** — Prometheus `http://localhost:9090/targets` မှာ `dtm-app` = UP။ 401 ပြရင် user/password သို့မဟုတ် permitUrls မှား၊ 404 ပြရင် path မှား၊ အပြင် (public domain) ကနေ `curl https://ကိုယ့်domain/actuator/prometheus` လုပ်ရင် **404** ပြရမယ် (200 ပြရင် ဖွင့်ထားမိနေတယ်)။

မှတ်ချက်: Spring Boot ရဲ့ `management.server.port` (သီးသန့် port) နည်းလည်း ရှိတယ်၊ ဒါပေမယ့် ကိုယ့် SecurityConfig နဲ့ ဘယ်လိုအလုပ်လုပ်မလဲ ကျွန်တော် မစမ်းနိုင်လို့ ဒီမှာ မထည့်ထားပါ။

## ၅.၂။ Postgres monitoring ဖွင့်ရန်

`POSTGRES_ENABLE=true` ဆိုရင် Postgres Dashboard ("DTM Postgres") နဲ့ Alert ၄ ခု (Postgres down, connection ၈၀% ကျော်, deadlock, transaction ၁၀ မိနစ်ကျော်ပွင့်နေ) ဖွင့်မယ်။
`postgres-exporter` container ကို kit က အလိုအလျောက် တပ်ပေးတယ် (သီးသန့် install မလို)။

**၁။ Monitor user ဆောက် (Postgres ထဲမှာ — admin user နဲ့ တစ်ခါပဲ)**

```sql
CREATE USER dtm_monitor WITH PASSWORD 'ကိုယ့်password';
GRANT pg_monitor TO dtm_monitor;
```

`pg_monitor` က ဖတ်ခွင့်သက်သက်ပဲ — data ကို မဖတ်၊ မပြင်နိုင်ဘူး။ Password မှာ space နဲ့ `" ' $ # \` မထည့်ပါနဲ့ (script က ပယ်မယ်)။

**၂။ `.env` ဖြည့်**

```
POSTGRES_ENABLE=true
POSTGRES_HOST=host.docker.internal
POSTGRES_PORT=5432
POSTGRES_DB=dtm_e_services
POSTGRES_USER=dtm_monitor
POSTGRES_PASSWORD=ကိုယ့်password
```

**၃။ Run** — `scripts\up.ps1` (Linux: `bash scripts/up.sh`). Prometheus/Grafana ကို အလိုအလျောက် restart လုပ်ပေးမယ်။

**၄။ စစ်** — Prometheus `http://localhost:9090/targets` မှာ `postgres` = UP ဖြစ်ရမယ်၊ Grafana မှာ **DTM Postgres** dashboard မှာ "Postgres up" = UP။
DOWN ဖြစ်ရင် `docker compose logs postgres-exporter` ကြည့် (password/user/DB နာမည်မှား၊ သို့မဟုတ် Postgres က Docker ကနေ ချိတ်ခွင့်မပေး — `pg_hba.conf` / `listen_addresses` စစ်)။

ပိတ်ချင်ရင် `POSTGRES_ENABLE=false` လုပ်ပြီး up ပြန် run — exporter container ကိုပါ ဖယ်ပေးမယ်။
Container အကုန် ရပ်ချင်ရင် `scripts\down.ps1` (ဒေတာ မပျက်)။

## ၅.၃။ Uptime check (URL စစ်ခြင်း) ဖွင့်ရန်

Website/API ကို အပြင်ကလူသုံးသူလို URL နဲ့ တကယ်ခေါ်ကြည့်ပြီး ဖွင့်လို့ရလား၊ မြန်လား၊ HTTPS certificate ဘယ်နှရက်ကျန်လဲ စစ်တယ်။
App Metrics က app အတွင်းက ပြောတာ၊ Uptime check က အပြင်ကနေ အစစ်ဝင်ကြည့်တာ (nginx/DNS/port/certificate ပြဿနာကိုပါ မိတယ်)။
`blackbox-exporter` container ကို kit က အလိုအလျောက် တပ်ပေးတယ်။

`.env` ထဲ:

```
UPTIME_ENABLE=true
UPTIME_URLS=http://localhost:8080/actuator/health,https://dtm.gov.mm
```

ပြီးရင် `scripts\up.ps1` (Linux: `bash scripts/up.sh`) run။ Grafana မှာ **Uptime** dashboard (URL တစ်ခုချင်း UP/DOWN၊ ၂၄ နာရီ uptime %၊ response time၊ HTTP status၊ cert ကျန်ရက်) ပေါ်မယ်။

- Alert ၂ ခု: **URL down** (၂ မိနစ်ကျော်ဖွင့်မရ၊ critical) နဲ့ **HTTPS certificate expiring** (၁၄ ရက်အတွင်းကုန်မယ်၊ warning)။
- 2xx ကိုပဲ OK လို့ သတ်မှတ်တယ်။ 404/500/timeout (၁၀ စက္ကန့်) ဆို DOWN။ Redirect ကို လိုက်ကြည့်တယ်။
- Login လိုတဲ့ URL ကို စစ်ရင် 401 ကြောင့် DOWN ပြမယ်၊ `/actuator/health` လို public URL ကိုပဲ ထည့်ပါ။
- ပြင်ချင်တဲ့ စစ်ပုံ (timeout, status code) ကို `features/uptime/blackbox.yml` မှာ ပြင်။
- ပိတ်ချင်ရင် `UPTIME_ENABLE=false` လုပ်ပြီး up ပြန် run။

## ၅.၄။ Alert စာပုံစံ (Message template) ပြင်ရန်

Telegram နဲ့ Email ကို ပို့တဲ့စာကို Grafana မူလပုံစံ (ရှည်၊ အင်္ဂလိပ်လို၊ label တွေအများကြီး) အစား ဒီလို ရိုးရှင်းတဲ့ မြန်မာစာပုံစံနဲ့ ပို့မယ်:

```
🔴 ပြဿနာ ဖြစ်နေတယ်
DTM app metrics down
DTM backend ကို ၂ မိနစ်ကျော် ချိတ်မရဘူး ...
🌐 dev  📍 host.docker.internal:8080
🕒 2026-10-23 12:30:00
```

ပြန်ကောင်းလာရင် 🟢 ပြန်ကောင်းသွားပြီ ဆိုပြီး ပို့မယ်။ Email ရဲ့ subject က `🔴 ပြဿနာ: alert နာမည်` ပုံစံ။

**ပြင်ချင်ရင်:** `grafana/alerting/common/templates.yaml` ကိုဖွင့်ပြီး စာ၊ emoji၊ အစီအစဉ်ကို ကြိုက်သလိုပြင် → `scripts\up.ps1` ပြန် run (Grafana ကို အလိုအလျောက် restart လုပ်ပေးမယ်)။
ဖိုင်ထိပ်မှာ ပြင်ရာမှာ သတိထားရမယ့်အချက်တွေ ရေးထားတယ် (`$` မသုံးရ၊ Telegram က HTML mode ဆိုတာ ...)။
ဒေတာနေရာ (`{{ .Labels.alertname }}` စတာ) ကိုပဲ မထိဘဲ ဘေးက စာကို ပြင်ရင် အန္တရာယ်မရှိဘူး။

**`.env` setting ၂ ခု:**

| Setting | အဓိပ္ပါယ် |
|---|---|
| `ALERT_TEMPLATE_ENABLE=true` | kit ရဲ့ ပုံစံသုံး (မူလ)။ `false` = Grafana မူလပုံစံပြန်သုံး |
| `ALERT_TIMEZONE=Asia/Yangon` | စာထဲက အချိန် time zone။ Template error ပေါ်ရင် `UTC` လို့ ပြောင်းကြည့် |

**စမ်းကြည့်နည်း:** Grafana > Alerting > Contact points > `telegram-alerts` (သို့မဟုတ် `email-alerts`) > **Test** ခလုတ် — နမူနာ alert တစ်ခု ပို့ပေးတယ်။ ပို့ပြီးရင် စာပုံစံမှန်လား၊ အချိန် မှန်လား ကြည့်ပါ။

## ၆။ နေ့စဉ် အသုံးပြုပုံ

| လုပ်ချင်တာ | Command |
|---|---|
| စတင် | `scripts\up.ps1` (Linux: `bash scripts/up.sh`) |
| ရပ် (data ကျန်) | `docker compose down` |
| အခြေအနေ | `docker compose ps` |
| Log ကြည့် | `docker compose logs -f grafana` (သို့ `alloy`, `loki`, `prometheus`) |
| Setting ပြင်ပြီး ပြန်စ | `scripts\up.ps1` ပြန် run |
| အားလုံး စစ် | `scripts\check.ps1` (Linux: `bash scripts/check.sh`) |

> ⚠️ **`docker compose down -v`** ကို မသုံးပါနဲ့။ `-v` က data volume တွေကို ဖျက်ပြီး Dashboard/Log/မှတ်တမ်း အကုန်ပျောက်ပါတယ်။

Computer ပြန်ဖွင့်ရင် Docker Desktop စတင်တာနဲ့ container တွေ အလိုအလျောက် ပြန်တက်ပါတယ် (`restart: unless-stopped`)။ ဒါပေမယ့် Docker Desktop ကို Windows စတင်တာနဲ့အတူ စတင်ဖို့ Docker Desktop Settings ထဲမှာ "Start Docker Desktop when you sign in" ကို ဖွင့်ထားပါ။

---

## ၇။ တခြား project / server ထပ်ထည့်ရန်

**Log ထပ်ထည့်** — `LOG_DIR` folder ထဲကို `*.log` ဖိုင်အသစ် ထည့်ရုံပါပဲ (ဖိုင်နာမည်က service နာမည်)။ တခြား folder က log လည်း ဖတ်ချင်ရင် `compose.yaml` ရဲ့ alloy `volumes` မှာ mount ထပ်ထည့်ပြီး `alloy/config.alloy` ထဲက `__path__` ကို ထပ်တိုးပါ။

**Server / စက် ထပ်ထည့်** — `prometheus/prometheus.<windows|linux>.yml` ရဲ့ `scrape_configs` ထဲ job အသစ်ထည့်ပါ။

```yaml
  - job_name: other-server
    static_configs:
      - targets: ['192.168.1.20:9100']
        labels: { env: prod, host: other-server }
```

---

## ၈။ Linux (Staging / Production) မှာ သုံးရင်

Linux server အတွက် သီးခြား ခွဲပြီး ပါပြီးသားပါ — Prometheus config၊ Alert rule ၅ ခု၊ Host Dashboard၊ script ၃ ခု။ Windows နဲ့ ရောမနေပါဘူး။

**လိုအပ်တာ:** Docker Engine + Docker Compose v2၊ `curl`၊ systemd ရှိတဲ့ Linux (Ubuntu/Debian/RHEL...)၊ sudo ရပိုင်ခွင့်။

**အဆင့် ၁ — Setting ဖြည့်**

```bash
cp .env.example .env
nano .env      # PLATFORM=linux လို့ပြောင်း၊ ကျန်တာ (password, email, SMTP, LOG_DIR) ဖြည့်
```

`LOG_DIR` ကို app log ရေးတဲ့ folder ပေးပါ (ဥပမာ `/var/log/dtm`)။ `prometheus/prometheus.linux.yml` ထဲက `env:` (stag/prod) နဲ့ `host:` ကို ကိုယ့် server နာမည်နဲ့ ပြင်ပါ၊ `.env` ထဲက `MONITORING_ENV` / `MONITORING_HOST` နဲ့ တူအောင်ထားပါ။

**အဆင့် ၂ — node_exporter install (server ပေါ်မှာ တစ်ခါပဲ)**

```bash
sudo bash scripts/install-node-exporter.sh
```

Script က node_exporter ကို download လုပ်၊ checksum စစ်၊ systemd service အဖြစ် တင်ပေးတယ်။ **Docker bridge IP (ပုံမှန် 172.17.0.1) မှာပဲ နားထောင်စေတယ်** — container တွေက မြင်နိုင်ပြီး၊ အပြင် network ကနေ မမြင်ရအောင်။

**အဆင့် ၃ — စတင်**

```bash
bash scripts/up.sh
```

**အဆင့် ၄ — စစ်**

```bash
sleep 30; bash scripts/check.sh
```

`ALL CHECKS PASSED` ပေါ်ရင် ပြီး။ Alert email စမ်းချင်ရင် `bash scripts/send-test-error.sh`။

**Linux မှာ သတိထားစရာ**

- Prometheus target **DOWN** ဖြစ်နေရင် Firewall (ufw/firewalld) က container → host `:9100` ကို ပိတ်ထားတာ များတယ်။ ufw ဆိုရင်: `sudo ufw allow from 172.16.0.0/12 to 172.17.0.1 port 9100 proto tcp`
- node_exporter service ရှိပြီးသားဆိုရင် script က မထိဘဲ ရပ်တယ်။ ရှိပြီးသားက `127.0.0.1` တစ်ခုတည်းမှာ နားထောင်နေရင် container က မမြင်ပါ — `--web.listen-address` ကို Docker bridge IP ပြောင်းပါ။
- Production မှာ Grafana ကို Internet ကို တိုက်ရိုက် မဖွင့်ပါနဲ့။ `127.0.0.1:3000` မှာပဲထားပြီး SSH tunnel သုံးပါ: `ssh -N -L 3000:127.0.0.1:3000 user@server`
- Staging/Production မှာ app က log ကို **file ထဲ** ရေးရမယ် (console ပဲရေးနေရင် Alloy ဖတ်စရာ ဖိုင်မရှိ)။ Spring Boot ဆိုရင် `LOGGING_FILE_NAME=/var/log/dtm/e-services.log` နဲ့ `LOGGING_STRUCTURED_FORMAT_FILE=ecs`။ Alloy container က log folder ကို read-only နဲ့ ဖတ်ရမှာမို့ ဖိုင်ကို လူတိုင်းဖတ်လို့ရတဲ့ permission (ဥပမာ 644) ထားပါ။
- Alert rule ၅ ခုက Windows နဲ့ အတူတူ (Backend ERROR, Exporter down, Disk >90%, Memory >90%, CPU >90%) ဖြစ်ပြီး Linux metric (`node_*`) နဲ့ ရေးထားတယ်။ Disk က tmpfs/overlay/squashfs စတဲ့ အတု filesystem တွေကို ဖယ်ထားတယ်။

---

## ၉။ လုံခြုံရေး မှတ်ချက်များ

- **`.env` ကို Git ထဲ မတင်ပါနဲ့** (ပါတဲ့ `.gitignore` က ကာထားပြီးသား)။ Password တွေ screenshot/chat ထဲ မပို့ပါနဲ့။
- Grafana ကို `127.0.0.1` ပဲ ဖွင့်ထားတယ် (LAN က မဝင်နိုင်)။ Prometheus/Loki/Alloy ကို အပြင်ကို မဖွင့်ထားဘူး (Docker network ထဲမှာပဲ)။ **Loki က login မရှိဘူး** ဆိုတော့ အပြင်ကို မဖွင့်ပါနဲ့။
- **windows_exporter ရဲ့ port 9182** ကို installer က Windows Firewall ထဲ ဖွင့်ပေးတယ်။ ပုံမှန်အားဖြင့် LAN ထဲက တခြားစက်တွေပါ ဝင်ကြည့်နိုင်နေနိုင်တယ်။ (ပေါက်ကြားရင် CPU/RAM/disk အချက်အလက်တွေပဲ မြင်ရတာမို့ အန္တရာယ်နည်းပေမယ့်) ရှင်းလင်းချင်ရင် Windows Defender Firewall မှာ `windows_exporter` rule ရဲ့ Remote IP ကို ကန့်သတ်ပါ။ Docker Desktop က ဘယ် IP ကနေ ချိတ်လာလဲ အရင်စစ်ပြီးမှ ကန့်သတ်ပါ၊ မဟုတ်ရင် Prometheus ချိတ်မရတော့ပါ။
- **Log ထဲမှာ အရေးကြီးအချက်အလက် (token, password, ကိုယ်ရေးအချက်အလက်) ပါနိုင်တယ်။** Grafana ကို ဝင်ခွင့်ရတဲ့သူတိုင်း မြင်ရမယ်။ Alloy ရဲ့ label ကန့်သတ်ချက်က log စာသားကို မဖျောက်ပေးပါဘူး။ Spring Security ကို TRACE/DEBUG ထားရင် log က အရမ်းများပြီး sensitive ဖြစ်နိုင်တယ်။
- Gmail App Password ပေါက်ကြားရင် Google Account ထဲမှာ ဖျက်ပြီး အသစ်ထုတ်ပါ၊ `.env` ကို update လုပ်ပြီး `up` script ပြန် run ပါ။
- Image version တွေကို ပုံသေထားတာ (`:latest` မသုံး)။ Production မတင်ခင် security update ရှိမရှိ ကိုယ်တိုင်စစ်ပြီး version ကို ဖြည်းဖြည်း မြှင့်ပါ။

---

## ၁၀။ ပြဿနာ ဖြေရှင်းနည်း

| ပြဿနာ | ဖြေရှင်းနည်း |
|---|---|
| `up` script က `... is empty in .env` လို့ပြောတယ် | `.env` ထဲက အဲဒီကွက်ကို ဖြည့်ပါ၊ ဒါမှမဟုတ် အဲဒီ feature ကို `*_ENABLE=false` လုပ်ပါ |
| `docker compose up` မှာ `.generated/...` bind mount မရှိဘူး | `docker compose` ကို တိုက်ရိုက်မခေါ်ဘဲ `up` script နဲ့ စတင်ပါ |
| `failed to connect to the docker API ... dockerDesktopLinuxEngine` | Docker Desktop ကို ဖွင့်ပါ၊ "Engine running" ဖြစ်တဲ့အထိ စောင့်ပါ |
| `port is already allocated` (3000) | `.env` မှာ `GRAFANA_PORT=3001` လို့ ပြောင်းပါ |
| Dashboard မှာ **Exporter up = DOWN** | Windows: `Get-Service windows_exporter` စစ်၊ http://localhost:9182/metrics ပွင့်လား၊ Firewall ကြည့်ပါ။ Linux: `systemctl status node_exporter`၊ `curl http://172.17.0.1:9100/metrics`၊ ufw/firewalld ကြည့်ပါ |
| `docker compose up` မှာ bind mount path မရှိဘူးဆိုတဲ့ error | `.env` ထဲက `PLATFORM` ကို `windows` ဒါမှမဟုတ် `linux` (အကြီးအသေးမှန်) ပဲ ထည့်ပါ |
| Log မပေါ်ဘူး | `logs\` ထဲမှာ `*.log` ဖိုင် ရှိလား၊ app က `LOGGING_FILE_NAME` ကို သတ်မှတ်ပြီး restart လုပ်ထားလား စစ်ပါ။ `docker compose logs alloy` ကြည့်ပါ |
| Log ပေါ်ပေမယ့် `level` မပါဘူး | Log က JSON မဟုတ်လို့ပါ (အပေါ် ၄ ကို ကြည့်ပါ) |
| Test email မရောက် | Spam ကြည့်ပါ။ `.env` ထဲက `SMTP_PASSWORD` မှာ space/quote မပါစေနဲ့။ `docker compose logs grafana` မှာ `smtp` ပါတဲ့ error ကိုရှာပါ။ `535 Username and Password not accepted` ဆိုရင် App Password မှား |
| Alert rule မပေါ်ဘူး | `docker compose logs grafana` မှာ `provisioning` / `alert` ပါတဲ့ error ကို ရှာပါ |
| Windows မှာ log ဖိုင်ကို ကိုယ်တိုင်ရေးတာ "being used by another process" | `scripts\send-test-error.ps1` ကို သုံးပါ (ဖိုင်ကို မျှဝေပြီးရေးတယ်) |
| Disk ပြည့်လာ | `docker system df` ကြည့်ပါ။ Loki က ၃၀ ရက်၊ Prometheus က ၁၅ ရက်ပဲ သိမ်းတယ်။ `loki/loki.yaml`, `compose.yaml` ထဲမှာ ပြင်ပါ |

---

## ၁၁။ စမ်းသပ်မှု အခြေအနေ (ရိုးသားစွာ)

**တကယ် စမ်းပြီး အောင်ထားတာ** (Linux, တကယ့် binary တွေနဲ့):

- `promtool` က `prometheus.windows.yml` နဲ့ `prometheus.linux.yml` နှစ်ခုလုံး မှန်ကန်တယ်ဆို
- Loki `-verify-config` က `loki.yaml` မှန်ကန်တယ်ဆို
- Alloy `fmt` / `validate` က `config.alloy` မှန်ကန်တယ်ဆို
- Loki + Alloy ကို တကယ် run ပြီး log ထည့်စမ်းတာ : label **`env, host, level, service` ၄ ခုသာ** ထွက်၊ ဖိုင်နာမည်ကနေ `service` ဖြစ်၊ `.gz` ဖိုင် မဖတ်၊ `{level="ERROR"}` ရေတွက်ခြင်း အလုပ်လုပ်
- **Linux:** node_exporter 1.9.1 + Prometheus ကို တကယ် run ပြီး Linux Alert rule ၄ ခု (Prometheus query) နဲ့ Linux Dashboard panel အားလုံးရဲ့ query ကို စမ်းတာ — အားလုံး data ပြန်ထွက်တယ်
- **Windows:** သင့်စက်မှာ windows_exporter + Docker နဲ့ dev stack ကို တကယ် run ပြီး Dashboard၊ log၊ Email alert (Firing → email ရောက်) အလုပ်လုပ်ကြောင်း အတည်ပြုပြီး
- `docker compose config` : `.env` မဖြည့်ရင် မြန်မာ error စာနဲ့ ရပ်၊ `PLATFORM` နှစ်မျိုးလုံး မှန်ကန်တဲ့ path ရွေး
- Shell script ၄ ခု (`up.sh` ပါ) ကို `bash -n` syntax စစ်
- **App Metrics:** Mock Spring Boot metrics server + Prometheus အစစ် (`scrape_config_files` နဲ့) ကို run ပြီး Dashboard panel ၁၁ ခု၊ Alert query ၄ ခု အားလုံး data ပြန်ထွက်ကြောင်း၊ `up` script က config ပြောင်းမှ Prometheus/Grafana ကို restart လုပ်ကြောင်း (Docker အတုနဲ့) စစ်ထား
- **Postgres:** Postgres 16 အစစ် + postgres_exporter v0.17.1 အစစ် + Prometheus အစစ်ကို run ပြီး Dashboard panel အားလုံးရဲ့ query၊ Alert query ၄ ခု data ပြန်ထွက်ကြောင်း၊ `up.sh`/`up.ps1` ကိုက်ညီကြောင်း၊ password မှားရင် ပယ်ကြောင်း စစ်ထား။ `postgres-exporter` compose service ကိုတော့ Docker နဲ့ မ run ရသေးပါ (သင့်စက်မှာ ပထမဆုံးအကြိမ်)
- **Uptime:** blackbox_exporter v0.27.0 အစစ် + Prometheus အစစ် + ဒေသတွင်း web server ကို run ပြီး UP(200)/DOWN(404, ချိတ်မရ) ခွဲပြတာ၊ Dashboard panel၊ Alert query စစ်ထား။ **HTTPS certificate panel/alert ကိုတော့ https အစစ်နဲ့ မစမ်းရသေးပါ** (sandbox က အပြင် website မခေါ်နိုင်လို့)။ `blackbox-exporter` compose service ကိုလည်း Docker နဲ့ မ run ရသေးပါ
- **App Metrics scheme/basic auth:** `up.sh`/`up.ps1` နှစ်ခုလုံး ထွက်တဲ့ scrape ဖိုင် တူကြောင်း၊ promtool မှန်ကြောင်း၊ မှားတဲ့ တန်ဖိုး ပယ်ကြောင်း စစ်ထား။ **နည်း A/B ရဲ့ nginx/firewall config နဲ့ Prometheus basic_auth ချိတ်ဆက်မှုကို တကယ့် server မှာ မစမ်းရသေးပါ**
- **Alert template:** ပုံစံကို Alertmanager ရဲ့ template engine နဲ့ render ပြီး firing/resolved၊ alert တစ်ခု/များစွာ၊ `&` `<` ပါတဲ့ ဒေတာမှာ ထွက်တဲ့စာကို စစ်ထား။ `up` script နှစ်ခုက ထုတ်တဲ့ဖိုင် တူကြောင်း၊ ON/OFF နှစ်မျိုးလုံး စစ်ထား။ **Grafana ကိုယ်တိုင်နဲ့ မစမ်းရသေးပါ** — `tz`/`date` function နဲ့ Telegram `parse_mode`/`message`၊ Email `subject`/`message` setting တွေက Grafana စာတမ်းအတိုင်း ရေးထားတာပဲ၊ ပထမဆုံး **Test** ခလုတ်နဲ့ စမ်းကြည့်ပါ
- `up.sh` နဲ့ `up.ps1` (PowerShell 7 နဲ့) ကို Docker အတု ထည့်ပြီး run ပြီး `EMAIL_ALERT_ENABLE` true/false/မရှိ၊ SMTP ဗလာ error ကိစ္စတွေမှာ ထွက်တဲ့ `.generated` ဖိုင် နှစ်ခုလုံး တူကြောင်းနဲ့ `docker compose config` ကိုက်ကြောင်း စစ်ထား

**မစမ်းရသေးတာ** (ကျွန်တော့်ဘက်မှာ Docker/Grafana မ run နိုင်လို့):

- **Telegram:** `test-telegram` script ကို Telegram အတု server နဲ့ပဲ စမ်းထား (တကယ့် bot နဲ့ မစမ်းရသေး)။ Grafana ရဲ့ Telegram contact point ဖိုင် (`contact-points.telegram.yaml`) ကိုလည်း Grafana နဲ့ မ load ရသေးပါ။
- **`up` script နဲ့ ထုတ်ပေးတဲ့ contact point / policy ဖိုင်ကို Grafana နဲ့ တကယ် load မစမ်းရသေးပါ။** Email တစ်ခုတည်းဖွင့်ရင် ထွက်တဲ့ဖိုင်က အရင်အလုပ်လုပ်ခဲ့တဲ့ဖိုင်နဲ့ တူတူပါ။ Channel အားလုံးပိတ်ရင် (`grafana-default-email` ကို သုံးတယ်) နဲ့ channel ၂ ခုထက်ပိုဖွင့်ရင် (`routes` + `continue`) ပုံစံကိုတော့ အတည်မပြုရသေးပါ။
- **ဒီ kit ထဲက Grafana provisioning ဖိုင်တွေ** (data source, dashboard JSON, alert rule, contact point, policy) ကို Grafana နဲ့ တကယ် load မစမ်းရသေးပါ။ ဖွဲ့စည်းပုံက Grafana စာတမ်းအတိုင်းနဲ့ သင့်စက်မှာ အလုပ်လုပ်ခဲ့တဲ့ ပုံစံအတိုင်းဆိုပေမယ့် version ကွာရင် schema ကွဲနိုင်ပါတယ်။
- `install-node-exporter.sh`, `check.sh`, `send-test-error.sh` ကို **တကယ့် Linux server + Docker ပေါ်မှာ မ run ရသေးပါ** (syntax စစ်ပဲ ရှိ)။ Docker bridge IP ရှာတာ၊ systemd unit၊ firewall အပိုင်းတွေ server ပေါ်မှာ ပြင်စရာ ရှိနိုင်တယ်။
- Kit ကို Windows Docker Desktop မှာ zip ကနေ အစကနေ ပြန်တပ်တာ မလုပ်ရသေးပါ။

ဒါကြောင့် **အဆင့် ၄ ရဲ့ check script (`check.ps1` / `check.sh`) ကို မဖြစ်မနေ run ပါ။** မအောင်တာရှိရင် `docker compose logs grafana` ရဲ့ output ကို ပို့ပေးပါ၊ ပြင်ပေးပါမယ်။
