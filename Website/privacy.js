const policyCopy = {
  ko: {
    eyebrow: "Privacy by design",
    title: "개인정보처리방침",
    lead: "NudgeMate는 캘린더와 준비 정보를 기기 안에서 처리하며, 무료 버전의 광고에 필요한 정보는 별도로 제한해 처리합니다.",
    effective: "시행일: 2026년 8월 18일",
    contact: "개인정보 관련 문의:",
    sections: [
      ["1. 처리하는 정보", "사용자가 선택한 캘린더의 일정 제목과 날짜, 앱에서 만든 리듬·준비 항목·설정은 기능 제공을 위해 기기에서만 처리됩니다. 개발자는 이 정보를 수집하거나 서버로 전송하지 않습니다."],
      ["2. 캘린더와 알림 권한", "캘린더 전체 접근은 반복 일정의 간격을 분석하고 사용자가 요청한 일정을 저장하는 데 사용됩니다. 알림 권한은 리듬, 준비 체크인과 Daily Recap을 전달하는 데 사용됩니다. 권한은 iOS 설정에서 언제든 변경할 수 있습니다."],
      ["3. 위젯과 Live Activity", "위젯과 Live Activity는 앱과 같은 기기의 App Group에 완료되지 않은 준비 최대 3개의 제목, 목표일, 상태와 다음 행동을 저장합니다. 이 정보는 외부로 전송되지 않습니다."],
      ["4. 구입 정보", "구독과 평생 이용권 결제는 Apple의 StoreKit과 App Store가 처리합니다. NudgeMate는 결제 수단이나 카드 정보를 수집하지 않으며, 기기에서 Apple이 검증한 상품 권한만 확인합니다."],
      ["5. 광고와 동의", "무료 사용자가 Daily Recap을 완료하면 Google Mobile Ads 전면 광고가 최대 24시간에 한 번 표시될 수 있습니다. Google User Messaging Platform은 해당 지역에서 광고 동의를 요청하고, 설정의 개인정보 선택에서 동의를 다시 변경할 수 있게 합니다. Pro 사용자는 광고 SDK를 시작하거나 광고를 요청하지 않습니다."],
      ["6. 광고 관련 데이터", "Google 광고 SDK는 광고 제공, 측정과 부정행위 방지를 위해 대략적 위치, 기기 식별자, 광고 데이터, 제품 상호 작용, 충돌·성능·진단 데이터를 처리할 수 있습니다. 캘린더 제목·날짜, 리듬과 준비 항목은 광고 SDK에 전달하지 않습니다. 현재 버전은 Apple의 ATT 권한을 요청하지 않습니다."],
      ["7. 보관, 내보내기와 삭제", "앱 데이터는 사용자의 기기에 보관됩니다. 설정에서 JSON으로 내보내거나 전체 삭제할 수 있습니다. 앱을 삭제하면 로컬 데이터도 제거되지만 App Store 구입 내역은 Apple 계정에 유지됩니다. 광고 동의 정보는 Google UMP 정책에 따라 관리됩니다."],
      ["8. 아동과 정책 변경", "NudgeMate는 계정을 만들거나 연령 정보를 수집하지 않습니다. 정책이 변경되면 이 페이지의 시행일을 갱신하며, 중요한 변경은 앱 또는 공개 페이지에서 안내합니다."]
    ]
  },
  en: {
    eyebrow: "Privacy by design",
    title: "Privacy Policy",
    lead: "NudgeMate processes calendar and preparation information on your device and separately limits the information used for ads in the free version.",
    effective: "Effective: August 18, 2026",
    contact: "Privacy questions:",
    sections: [
      ["1. Information processed", "Calendar titles and dates from calendars you select, along with rhythms, preparation items, and settings you create, are processed only on your device to provide app features. The developer does not collect or transmit this information."],
      ["2. Calendar and notification permissions", "Full calendar access is used to analyze recurring intervals and save events you request. Notification access is used for rhythms, preparation check-ins, and Daily Recap. You can change permissions at any time in iOS Settings."],
      ["3. Widgets and Live Activities", "Widgets and Live Activities store the title, target date, status, and next action for up to three incomplete preparation items in the app's on-device App Group. This information is not transmitted externally."],
      ["4. Purchase information", "Subscriptions and the lifetime purchase are processed by Apple's StoreKit and App Store. NudgeMate does not collect payment card or payment method details and only checks product entitlements verified by Apple on the device."],
      ["5. Advertising and consent", "After a free user completes Daily Recap, a Google Mobile Ads interstitial may appear at most once every 24 hours. Google User Messaging Platform requests advertising consent where required and lets you revisit those choices from Settings. Pro users do not initialize the ads SDK or request ads."],
      ["6. Advertising data", "Google's ads SDK may process coarse location, device identifiers, advertising data, product interaction, crash, performance, and diagnostic data to serve and measure ads and prevent fraud. Calendar titles and dates, rhythms, and preparation items are not sent to the ads SDK. This version does not request Apple's App Tracking Transparency permission."],
      ["7. Retention, export, and deletion", "App data remains on your device. You can export it as JSON or delete all app data in Settings. Deleting the app removes local data, while App Store purchase history remains with your Apple Account. Advertising consent information is managed under Google UMP policies."],
      ["8. Children and policy changes", "NudgeMate does not create accounts or collect age information. If this policy changes, the effective date on this page will be updated and material changes will be announced in the app or on this public page."]
    ]
  },
  "zh-Hans": {
    eyebrow: "Privacy by design",
    title: "隐私政策",
    lead: "NudgeMate 在设备端处理日历和准备信息，并对免费版广告所需的信息进行单独、有限的处理。",
    effective: "生效日期：2026年8月18日",
    contact: "隐私问题联系：",
    sections: [
      ["1. 处理的信息", "你所选日历的标题和日期，以及在 App 中创建的节奏、准备项目和设置，仅在设备上用于提供功能。开发者不会收集或传输这些信息。"],
      ["2. 日历和通知权限", "日历完整访问权限用于分析重复间隔并保存你要求创建的日程。通知权限用于节奏提醒、准备确认和每日回顾。你可以随时在 iOS 设置中更改权限。"],
      ["3. 小组件和实时活动", "小组件和实时活动通过设备端 App Group 保存最多三个未完成准备项目的标题、目标日期、状态和下一步行动。这些信息不会传输到外部。"],
      ["4. 购买信息", "订阅和终身购买由 Apple StoreKit 与 App Store 处理。NudgeMate 不收集银行卡或付款方式信息，只在设备上检查 Apple 验证的商品权益。"],
      ["5. 广告与同意", "免费用户完成 Daily Recap 后，Google Mobile Ads 插页式广告最多每 24 小时显示一次。Google User Messaging Platform 会在适用地区请求广告同意，并允许你在设置的隐私选项中重新选择。Pro 用户不会启动广告 SDK 或请求广告。"],
      ["6. 广告相关数据", "Google 广告 SDK 可能为了提供和衡量广告及防止欺诈而处理大致位置、设备标识符、广告数据、产品互动、崩溃、性能和诊断数据。日历标题和日期、节奏及准备项目不会发送给广告 SDK。当前版本不会请求 Apple 的 App 跟踪透明度权限。"],
      ["7. 保存、导出与删除", "App 数据保存在你的设备上。你可以在设置中导出 JSON 或删除所有 App 数据。删除 App 会移除本地数据，但 App Store 购买记录仍保留在 Apple 账户中。广告同意信息按照 Google UMP 政策管理。"],
      ["8. 儿童与政策变更", "NudgeMate 不创建账户，也不收集年龄信息。如本政策发生变化，我们会更新本页生效日期，并通过 App 或本公开页面说明重大变更。"]
    ]
  },
  "zh-Hant": {
    eyebrow: "Privacy by design",
    title: "隱私權政策",
    lead: "NudgeMate 在裝置端處理行事曆與準備資訊，並對免費版廣告所需的資訊進行獨立且有限的處理。",
    effective: "生效日期：2026年8月18日",
    contact: "隱私問題聯絡：",
    sections: [
      ["1. 處理的資訊", "你所選行事曆的標題與日期，以及在 App 中建立的節奏、準備項目與設定，只會在裝置上用於提供功能。開發者不會收集或傳送這些資訊。"],
      ["2. 行事曆與通知權限", "完整行事曆權限用於分析重複間隔，並儲存你要求建立的行程。通知權限用於節奏提醒、準備確認與每日回顧。你可以隨時在 iOS 設定中變更權限。"],
      ["3. 小工具與即時動態", "小工具與即時動態透過裝置端 App Group 儲存最多三個未完成準備項目的標題、目標日期、狀態與下一步行動。這些資訊不會傳送到外部。"],
      ["4. 購買資訊", "訂閱與終身購買由 Apple StoreKit 與 App Store 處理。NudgeMate 不會收集信用卡或付款方式資訊，只在裝置上檢查 Apple 驗證的商品權益。"],
      ["5. 廣告與同意", "免費使用者完成 Daily Recap 後，Google Mobile Ads 插頁式廣告最多每 24 小時顯示一次。Google User Messaging Platform 會在適用地區要求廣告同意，並讓你在設定的隱私權選項中重新選擇。Pro 使用者不會啟動廣告 SDK 或要求廣告。"],
      ["6. 廣告相關資料", "Google 廣告 SDK 可能為了提供與衡量廣告及防止詐騙，處理概略位置、裝置識別碼、廣告資料、產品互動、當機、效能和診斷資料。行事曆標題與日期、節奏及準備項目不會傳送給廣告 SDK。目前版本不會要求 Apple 的 App 追蹤透明度權限。"],
      ["7. 保存、匯出與刪除", "App 資料保存在你的裝置上。你可以在設定中匯出 JSON 或刪除所有 App 資料。刪除 App 會移除本機資料，但 App Store 購買紀錄仍保留於 Apple 帳號。廣告同意資訊依 Google UMP 政策管理。"],
      ["8. 兒童與政策變更", "NudgeMate 不建立帳號，也不收集年齡資訊。如本政策變更，我們會更新本頁生效日期，並透過 App 或本公開頁面說明重大變更。"]
    ]
  },
  ja: {
    eyebrow: "Privacy by design",
    title: "プライバシーポリシー",
    lead: "NudgeMateはカレンダーと準備情報をデバイス上で処理し、無料版の広告に必要な情報は分離して限定的に取り扱います。",
    effective: "施行日：2026年8月18日",
    contact: "プライバシーに関するお問い合わせ：",
    sections: [
      ["1. 処理する情報", "選択したカレンダーのタイトルと日付、アプリで作成したリズム、準備項目、設定は、機能提供のためデバイス上でのみ処理されます。開発者がこれらを収集または送信することはありません。"],
      ["2. カレンダーと通知の権限", "カレンダーへのフルアクセスは、繰り返し間隔の分析と依頼された予定の保存に使用します。通知権限はリズム、準備チェックイン、Daily Recapに使用します。権限はiOS設定でいつでも変更できます。"],
      ["3. ウィジェットとライブアクティビティ", "ウィジェットとライブアクティビティは、未完了の準備項目最大3件のタイトル、目標日、状態、次の行動をデバイス上のApp Groupに保存します。外部には送信されません。"],
      ["4. 購入情報", "サブスクリプションと買い切り購入はAppleのStoreKitとApp Storeが処理します。NudgeMateはカードや支払い方法を収集せず、Appleが検証した製品権利だけをデバイス上で確認します。"],
      ["5. 広告と同意", "無料ユーザーがDaily Recapを完了すると、Google Mobile Adsのインタースティシャル広告が最大24時間に1回表示される場合があります。Google User Messaging Platformは対象地域で広告への同意を求め、設定のプライバシー選択から変更できるようにします。Proユーザーは広告SDKを起動せず、広告もリクエストしません。"],
      ["6. 広告関連データ", "Googleの広告SDKは、広告の配信・測定と不正防止のため、おおよその位置情報、デバイス識別子、広告データ、製品操作、クラッシュ、パフォーマンス、診断データを処理する場合があります。カレンダーのタイトルと日付、リズム、準備項目は広告SDKに送信しません。現在のバージョンはAppleのApp Tracking Transparency権限を要求しません。"],
      ["7. 保存、書き出し、削除", "アプリデータはデバイスに保存されます。設定からJSONで書き出すか、すべて削除できます。アプリを削除するとローカルデータは消去されますが、App Storeの購入履歴はApple Accountに残ります。広告同意情報はGoogle UMPのポリシーに従って管理されます。"],
      ["8. お子様とポリシー変更", "NudgeMateはアカウントを作成せず、年齢情報を収集しません。本ポリシーを変更する場合はこのページの施行日を更新し、重要な変更をアプリまたは公開ページで案内します。"]
    ]
  }
};

const supported = Object.keys(policyCopy);
const languageSelect = document.querySelector("#locale");

function preferredLanguage() {
  const query = new URLSearchParams(location.search).get("lang");
  if (supported.includes(query)) return query;
  const stored = localStorage.getItem("nudgemate.locale");
  if (supported.includes(stored)) return stored;
  const browser = navigator.language || "ko";
  if (browser.toLowerCase().startsWith("zh-hant") || /zh-(tw|hk|mo)/i.test(browser)) return "zh-Hant";
  if (browser.toLowerCase().startsWith("zh")) return "zh-Hans";
  return supported.find((locale) => browser.toLowerCase().startsWith(locale.toLowerCase())) || "en";
}

function render(locale) {
  const content = policyCopy[locale] || policyCopy.en;
  document.documentElement.lang = locale;
  document.title = `${content.title} · NudgeMate`;
  languageSelect.value = locale;
  document.querySelectorAll("[data-copy]").forEach((element) => {
    element.textContent = content[element.dataset.copy] || "";
  });
  document.querySelector("#policy").innerHTML = content.sections.map(([title, body], index) => `
    <section style="--i:${index}">
      <h2>${title}</h2>
      <p>${body}</p>
    </section>
  `).join("");
  localStorage.setItem("nudgemate.locale", locale);
}

languageSelect.addEventListener("change", (event) => {
  const locale = event.target.value;
  const url = new URL(location.href);
  url.searchParams.set("lang", locale);
  history.replaceState({}, "", url);
  render(locale);
});

render(preferredLanguage());
