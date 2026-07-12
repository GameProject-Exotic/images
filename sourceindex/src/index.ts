import { chromium, Browser, Page } from 'playwright';
import * as path from 'path';
import * as fs from 'fs';
import * as fsp from 'fs/promises'

const RES_DIR_PATH = path.join(__dirname, '..', 'res');
const RES_RAW_DIR_PATH = path.join(RES_DIR_PATH, 'raw');
const RES_MLIST_FILE_PATH = path.join(RES_DIR_PATH, 'mlist.txt');
const RES_NLIST_FILE_PATH = path.join(RES_DIR_PATH, 'nlist.txt');

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const ROOT_PAGE_URL = 'https://sourceindex.net/';
const MAP_PAGE_URL = `${ROOT_PAGE_URL}maps/`;

const MIMAGE_CONTAINER_ID = 'screenshots';
const MIMAGE_URL_ATTRIBUTE_NAME = 'data-full';

async function main() {
  if (!fs.existsSync(RES_RAW_DIR_PATH)) {
    fs.mkdirSync(RES_RAW_DIR_PATH, {
      recursive: true
    });
  }

  let browser: Browser | null = null;
  try {
    browser = await chromium.launch({
      headless: true
    })
    const page = await browser.newPage();
    await page.setExtraHTTPHeaders({
      'User-Agent': USER_AGENT
    });

    await page.goto(ROOT_PAGE_URL, {
      waitUntil: 'domcontentloaded'
    });

    const mlist = await read(RES_MLIST_FILE_PATH);
    for (let i = 0; i < mlist.length;) {
      const mname = mlist[i++];

      await page.goto(`${MAP_PAGE_URL}${mname}`, {
        waitUntil: 'networkidle',
        timeout: 300000
      });

      const urls = await page.$$eval(`#${MIMAGE_CONTAINER_ID} .shot-card img`, (imgs, attr) => {
        return imgs.map(img => img.getAttribute(attr));
      }, MIMAGE_URL_ATTRIBUTE_NAME);
      if (!urls || urls.length === 0) {
        continue;
      }

      let url = urls[0];
      if (!url) {
        continue;
      }
      url = new URL(url, page.url()).href;

      const response = await page.request.get(url);
      if (!response.ok()) {
        continue;
      }

      const filext = url.split('.')
        .pop();
      const filepath = path.join(RES_RAW_DIR_PATH, `${mname}.${filext}`);

      const buff = await response.body();
      await fsp.writeFile(filepath, buff);

      console.log(`~${i}/${mlist.length}\t[${mname}]\t${url}`);
    }
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

async function read(f: string): Promise<string[]> {
  try {
    const text = await fsp.readFile(f, 'utf-8')
    return text.split('\n')
      .map((x: string) => x.trim())
      .filter((x: string) => x !== '');
  } catch {
  }

  return [];
}

async function sleep(t: number): Promise<void> {
  return new Promise(r => setTimeout(r, t));
}

main();
