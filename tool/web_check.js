// Vérifie la version web dans Chromium : la base s'ouvre et les données
// restent après rechargement de la page.
const { chromium } = require('playwright');

(async () => {
  const url = process.argv[2] || 'http://localhost:8080/mcs-facture/';
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(m.text()));
  page.on('pageerror', (e) => logs.push('PAGEERROR ' + e.message));

  async function opens() {
    const start = Date.now();
    while (Date.now() - start < 60000) {
      const ok = logs.find((l) => l.includes('MCS_DB_OK'));
      const err = logs.find((l) => l.includes('MCS_DB_ERROR'));
      if (err) throw new Error(err);
      if (ok) return parseInt(ok.split('opens=')[1], 10);
      await page.waitForTimeout(500);
    }
    throw new Error('Pas de message MCS_DB_OK. Journal :\n' + logs.join('\n'));
  }

  await page.goto(url);
  const a = await opens();
  await page.waitForTimeout(3000); // laisser le temps d'écrire dans IndexedDB
  logs.length = 0;
  await page.reload();
  const b = await opens();
  console.log(`Ouverture 1 : ${a}, ouverture 2 : ${b}`);
  await browser.close();
  if (b !== a + 1) {
    console.error('ÉCHEC : les données ne sont pas conservées.');
    process.exit(1);
  }
  console.log('OK : les données sont conservées.');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
