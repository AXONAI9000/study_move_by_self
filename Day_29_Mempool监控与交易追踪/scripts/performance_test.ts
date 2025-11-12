/**
 * Day 29: 性能测试
 * 
 * 测试监控系统的性能
 */

import { AptosClient } from 'aptos';

const NODE_URL = process.env.NODE_URL || 'https://fullnode.testnet.aptoslabs.com/v1';

class PerformanceTester {
  private client: AptosClient;

  constructor(nodeUrl: string) {
    this.client = new AptosClient(nodeUrl);
  }

  async testLatency(iterations: number = 10) {
    console.log(`\n🔬 Testing API Latency (${iterations} iterations)...\n`);

    const latencies: number[] = [];

    for (let i = 0; i < iterations; i++) {
      const start = Date.now();
      await this.client.getLedgerInfo();
      const latency = Date.now() - start;
      latencies.push(latency);
      console.log(`  Iteration ${i + 1}: ${latency}ms`);
    }

    const avg = latencies.reduce((a, b) => a + b) / latencies.length;
    const min = Math.min(...latencies);
    const max = Math.max(...latencies);

    console.log(`\n📊 Latency Stats:`);
    console.log(`   Average: ${avg.toFixed(2)}ms`);
    console.log(`   Min: ${min}ms`);
    console.log(`   Max: ${max}ms`);

    return { avg, min, max };
  }

  async testThroughput(duration: number = 10000) {
    console.log(`\n🔬 Testing Throughput (${duration}ms)...\n`);

    const startTime = Date.now();
    let requestCount = 0;
    let errorCount = 0;

    while (Date.now() - startTime < duration) {
      try {
        await this.client.getLedgerInfo();
        requestCount++;
      } catch (error) {
        errorCount++;
      }
    }

    const actualDuration = Date.now() - startTime;
    const rps = (requestCount / actualDuration) * 1000;

    console.log(`📊 Throughput Stats:`);
    console.log(`   Total Requests: ${requestCount}`);
    console.log(`   Errors: ${errorCount}`);
    console.log(`   Duration: ${actualDuration}ms`);
    console.log(`   Requests/sec: ${rps.toFixed(2)}`);

    return { requestCount, errorCount, rps };
  }

  async testBatchQueries(batchSize: number = 10) {
    console.log(`\n🔬 Testing Batch Queries (batch size: ${batchSize})...\n`);

    // 串行查询
    console.log('📍 Sequential queries...');
    const seqStart = Date.now();
    for (let i = 0; i < batchSize; i++) {
      await this.client.getLedgerInfo();
    }
    const seqDuration = Date.now() - seqStart;
    console.log(`   Time: ${seqDuration}ms`);

    // 并行查询
    console.log('📍 Parallel queries...');
    const parStart = Date.now();
    const promises = [];
    for (let i = 0; i < batchSize; i++) {
      promises.push(this.client.getLedgerInfo());
    }
    await Promise.all(promises);
    const parDuration = Date.now() - parStart;
    console.log(`   Time: ${parDuration}ms`);

    console.log(`\n📊 Improvement: ${((seqDuration - parDuration) / seqDuration * 100).toFixed(2)}%`);

    return { seqDuration, parDuration };
  }
}

async function main() {
  const tester = new PerformanceTester(NODE_URL);

  // 测试延迟
  await tester.testLatency(10);

  // 测试吞吐量
  await tester.testThroughput(5000);

  // 测试批量查询
  await tester.testBatchQueries(10);
}

if (require.main === module) {
  main().catch(console.error);
}

export { PerformanceTester };
