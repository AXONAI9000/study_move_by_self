/**
 * Day 29: Mempool 监控器
 * 
 * 实时监控 Aptos Fullnode 的新交易
 */

import { AptosClient } from 'aptos';

const NODE_URL = process.env.NODE_URL || 'https://fullnode.testnet.aptoslabs.com/v1';
const POLL_INTERVAL = 2000; // 2秒

class MempoolMonitor {
  private client: AptosClient;
  private lastVersion: number = 0;
  private running: boolean = false;
  private intervalId: NodeJS.Timer | null = null;

  constructor(nodeUrl: string) {
    this.client = new AptosClient(nodeUrl);
  }

  async start() {
    console.log('🚀 Starting Mempool Monitor...');
    
    // 获取当前版本
    const ledger = await this.client.getLedgerInfo();
    this.lastVersion = Number(ledger.ledger_version);
    console.log(`📊 Current ledger version: ${this.lastVersion}`);

    this.running = true;
    this.intervalId = setInterval(() => this.poll(), POLL_INTERVAL);
  }

  stop() {
    console.log('🛑 Stopping Mempool Monitor...');
    this.running = false;
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
  }

  private async poll() {
    try {
      const ledger = await this.client.getLedgerInfo();
      const currentVersion = Number(ledger.ledger_version);

      if (currentVersion > this.lastVersion) {
        const newTxCount = currentVersion - this.lastVersion;
        console.log(`\n✨ Found ${newTxCount} new transactions`);

        // 获取新交易
        const transactions = await this.client.getTransactions({
          start: this.lastVersion + 1,
          limit: Math.min(newTxCount, 100)
        });

        for (const tx of transactions) {
          this.processTransaction(tx);
        }

        this.lastVersion = currentVersion;
      }
    } catch (error) {
      console.error('❌ Poll error:', error);
    }
  }

  private processTransaction(tx: any) {
    console.log(`\n📝 Transaction: ${tx.hash}`);
    console.log(`   Sender: ${tx.sender}`);
    console.log(`   Success: ${tx.success}`);
    console.log(`   Gas Used: ${tx.gas_used}`);
    
    if (tx.payload && tx.payload.type === 'entry_function_payload') {
      console.log(`   Function: ${tx.payload.function}`);
    }
  }
}

// 运行监控器
async function main() {
  const monitor = new MempoolMonitor(NODE_URL);
  await monitor.start();

  // Ctrl+C 优雅退出
  process.on('SIGINT', () => {
    monitor.stop();
    process.exit(0);
  });
}

if (require.main === module) {
  main().catch(console.error);
}

export { MempoolMonitor };
