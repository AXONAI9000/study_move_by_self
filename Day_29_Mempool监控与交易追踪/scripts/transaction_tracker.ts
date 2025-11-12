/**
 * Day 29: 交易追踪器
 * 
 * 追踪交易从提交到确认的全过程
 */

import { AptosClient } from 'aptos';

const NODE_URL = process.env.NODE_URL || 'https://fullnode.testnet.aptoslabs.com/v1';

enum TxStatus {
  PENDING = 'pending',
  CONFIRMED = 'confirmed',
  FAILED = 'failed',
  TIMEOUT = 'timeout'
}

interface TrackedTx {
  hash: string;
  submitTime: number;
  confirmTime?: number;
  status: TxStatus;
  gasUsed?: number;
}

class TransactionTracker {
  private client: AptosClient;
  private tracked = new Map<string, TrackedTx>();

  constructor(nodeUrl: string) {
    this.client = new AptosClient(nodeUrl);
  }

  async track(txHash: string, timeout: number = 30000): Promise<TrackedTx> {
    const submitTime = Date.now();
    const deadline = submitTime + timeout;

    console.log(`🔍 Tracking transaction: ${txHash}`);

    const tracked: TrackedTx = {
      hash: txHash,
      submitTime,
      status: TxStatus.PENDING
    };

    this.tracked.set(txHash, tracked);

    while (Date.now() < deadline) {
      try {
        const tx = await this.client.getTransactionByHash(txHash);
        
        const confirmTime = Date.now();
        tracked.status = (tx as any).success ? TxStatus.CONFIRMED : TxStatus.FAILED;
        tracked.confirmTime = confirmTime;
        tracked.gasUsed = (tx as any).gas_used;

        const duration = confirmTime - submitTime;
        console.log(`✅ Transaction ${tracked.status} in ${duration}ms`);
        console.log(`   Gas Used: ${tracked.gasUsed}`);

        return tracked;
      } catch (error: any) {
        if (error.status === 404) {
          // 还在 Mempool，继续等待
          await this.sleep(1000);
          continue;
        }
        throw error;
      }
    }

    tracked.status = TxStatus.TIMEOUT;
    console.log(`⏱️  Transaction timeout after ${timeout}ms`);
    return tracked;
  }

  getTracked(txHash: string): TrackedTx | undefined {
    return this.tracked.get(txHash);
  }

  getStats() {
    const total = this.tracked.size;
    let confirmed = 0;
    let failed = 0;
    let timeout = 0;
    let totalConfirmTime = 0;

    for (const tx of this.tracked.values()) {
      if (tx.status === TxStatus.CONFIRMED) {
        confirmed++;
        if (tx.confirmTime) {
          totalConfirmTime += tx.confirmTime - tx.submitTime;
        }
      } else if (tx.status === TxStatus.FAILED) {
        failed++;
      } else if (tx.status === TxStatus.TIMEOUT) {
        timeout++;
      }
    }

    return {
      total,
      confirmed,
      failed,
      timeout,
      avgConfirmTime: confirmed > 0 ? totalConfirmTime / confirmed : 0
    };
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// 示例使用
async function main() {
  const tracker = new TransactionTracker(NODE_URL);

  // 需要一个真实的交易哈希
  const txHash = process.argv[2];
  if (!txHash) {
    console.log('Usage: ts-node transaction_tracker.ts <tx_hash>');
    process.exit(1);
  }

  try {
    await tracker.track(txHash, 30000);
    console.log('\n📊 Stats:', tracker.getStats());
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

if (require.main === module) {
  main().catch(console.error);
}

export { TransactionTracker, TxStatus };
