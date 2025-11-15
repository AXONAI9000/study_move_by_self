/**
 * Day 34 - Gas 分析工具
 * 
 * 使用 Aptos TypeScript SDK 分析和对比 Gas 消耗
 */

import { AptosClient, AptosAccount, TxnBuilderTypes, BCS } from "aptos";

// 配置
const NODE_URL = "https://fullnode.testnet.aptoslabs.com/v1";
const MODULE_ADDRESS = "0x..."; // 替换为实际地址

interface GasMetrics {
  functionName: string;
  gasUsed: number;
  executionGas: number;
  storageGas: number;
  ioGas: number;
}

interface ComparisonResult {
  baseline: GasMetrics;
  optimized: GasMetrics;
  savings: number;
  savingsPercent: number;
}

/**
 * 测量单个函数的 Gas 消耗
 */
async function measureGas(
  client: AptosClient,
  account: AptosAccount,
  functionName: string,
  args: any[] = [],
  typeArgs: string[] = []
): Promise<GasMetrics> {
  const payload = {
    function: `${MODULE_ADDRESS}::${functionName}`,
    type_arguments: typeArgs,
    arguments: args,
  };

  // 生成交易
  const rawTxn = await client.generateTransaction(account.address(), payload);

  // 模拟交易
  const simulation = await client.simulateTransaction(account, rawTxn);

  if (simulation.length === 0 || !simulation[0].success) {
    throw new Error(`Simulation failed for ${functionName}`);
  }

  const result = simulation[0];
  const gasUsed = parseInt(result.gas_used);

  return {
    functionName,
    gasUsed,
    executionGas: gasUsed * 0.3, // 估算
    storageGas: gasUsed * 0.6, // 估算
    ioGas: gasUsed * 0.1, // 估算
  };
}

/**
 * 对比两个实现的 Gas 消耗
 */
async function compareImplementations(
  client: AptosClient,
  account: AptosAccount,
  baselineFunc: string,
  optimizedFunc: string,
  args: any[] = []
): Promise<ComparisonResult> {
  console.log(`\n📊 对比分析: ${baselineFunc} vs ${optimizedFunc}`);
  console.log("=".repeat(60));

  const baseline = await measureGas(client, account, baselineFunc, args);
  const optimized = await measureGas(client, account, optimizedFunc, args);

  const savings = baseline.gasUsed - optimized.gasUsed;
  const savingsPercent = (savings / baseline.gasUsed) * 100;

  return {
    baseline,
    optimized,
    savings,
    savingsPercent,
  };
}

/**
 * 批量操作性能测试
 */
async function benchmarkBatchOperations(
  client: AptosClient,
  account: AptosAccount
) {
  console.log("\n🔬 批量操作性能基准测试");
  console.log("=".repeat(60));

  const batchSizes = [1, 10, 50, 100];
  const results: any[] = [];

  for (const size of batchSizes) {
    const recipients = Array(size).fill("0x1");
    const amounts = Array(size).fill(1000);

    const singleGas = await measureGas(
      client,
      account,
      "batch_operations::transfer_single",
      [recipients[0], amounts[0]]
    );

    const batchGas = await measureGas(
      client,
      account,
      "batch_operations::transfer_batch",
      [recipients, amounts]
    );

    const totalSingleGas = singleGas.gasUsed * size;
    const savings = totalSingleGas - batchGas.gasUsed;
    const savingsPercent = (savings / totalSingleGas) * 100;

    results.push({
      batchSize: size,
      singleTotal: totalSingleGas,
      batchTotal: batchGas.gasUsed,
      savings,
      savingsPercent,
    });

    console.log(`\n批次大小: ${size}`);
    console.log(`  单个操作×${size}: ${totalSingleGas.toLocaleString()} Gas`);
    console.log(`  批量操作:        ${batchGas.gasUsed.toLocaleString()} Gas`);
    console.log(`  节省:           ${savings.toLocaleString()} Gas (${savingsPercent.toFixed(2)}%)`);
  }

  return results;
}

/**
 * 存储优化对比
 */
async function benchmarkStorageOptimizations(
  client: AptosClient,
  account: AptosAccount
) {
  console.log("\n📦 存储优化对比");
  console.log("=".repeat(60));

  // 对比未打包 vs 打包存储
  const unpackedResult = await measureGas(
    client,
    account,
    "gas_optimized_storage::create_unpacked_config",
    []
  );

  const packedResult = await measureGas(
    client,
    account,
    "gas_optimized_storage::create_packed_config",
    [true, false, true, false, 5, 12345, 20, 15, 365, 0xFF00FF00]
  );

  console.log("\n未打包存储:");
  console.log(`  Gas 消耗: ${unpackedResult.gasUsed.toLocaleString()}`);

  console.log("\n打包存储:");
  console.log(`  Gas 消耗: ${packedResult.gasUsed.toLocaleString()}`);

  const savings = unpackedResult.gasUsed - packedResult.gasUsed;
  const savingsPercent = (savings / unpackedResult.gasUsed) * 100;

  console.log(`\n节省: ${savings.toLocaleString()} Gas (${savingsPercent.toFixed(2)}%)`);
}

/**
 * 计算优化对比
 */
async function benchmarkComputeOptimizations(
  client: AptosClient,
  account: AptosAccount
) {
  console.log("\n⚡ 计算优化对比");
  console.log("=".repeat(60));

  const testVector = Array(100)
    .fill(0)
    .map((_, i) => i + 1);

  // 循环优化
  const loopComparison = await compareImplementations(
    client,
    account,
    "gas_optimized_compute::sum_vector_unoptimized",
    "gas_optimized_compute::sum_vector_optimized",
    [testVector]
  );

  console.log("\n1. 循环优化 (缓存 length):");
  console.log(`   未优化: ${loopComparison.baseline.gasUsed.toLocaleString()} Gas`);
  console.log(`   优化后: ${loopComparison.optimized.gasUsed.toLocaleString()} Gas`);
  console.log(
    `   节省:   ${loopComparison.savings.toLocaleString()} Gas (${loopComparison.savingsPercent.toFixed(2)}%)`
  );

  // 条件分支优化
  const conditionComparison = await compareImplementations(
    client,
    account,
    "gas_optimized_compute::get_fee_rate_unoptimized",
    "gas_optimized_compute::get_fee_rate_optimized",
    [0]
  );

  console.log("\n2. 条件分支优化 (按概率排序):");
  console.log(`   未优化: ${conditionComparison.baseline.gasUsed.toLocaleString()} Gas`);
  console.log(`   优化后: ${conditionComparison.optimized.gasUsed.toLocaleString()} Gas`);
  console.log(
    `   节省:   ${conditionComparison.savings.toLocaleString()} Gas (${conditionComparison.savingsPercent.toFixed(2)}%)`
  );
}

/**
 * 生成综合报告
 */
function generateReport(results: {
  storage: any;
  compute: any;
  batch: any;
}) {
  console.log("\n" + "=".repeat(60));
  console.log("📄 Gas 优化综合报告");
  console.log("=".repeat(60));

  console.log("\n存储优化效果:");
  console.log(`  - 数据打包节省: ${results.storage.savingsPercent.toFixed(2)}%`);

  console.log("\n计算优化效果:");
  console.log(`  - 循环优化节省: ${results.compute.loopSavings.toFixed(2)}%`);
  console.log(`  - 条件优化节省: ${results.compute.conditionSavings.toFixed(2)}%`);

  console.log("\n批量操作效果:");
  results.batch.forEach((r: any) => {
    console.log(
      `  - 批次${r.batchSize}:  节省 ${r.savingsPercent.toFixed(2)}%`
    );
  });

  console.log("\n建议:");
  console.log("  ✓ 优先优化存储结构");
  console.log("  ✓ 对高频操作实施批量处理");
  console.log("  ✓ 缓存重复计算结果");
  console.log("  ✓ 使用位运算替代算术运算（适当时）");

  console.log("\n" + "=".repeat(60));
}

/**
 * 主函数
 */
async function main() {
  console.log("🚀 Day 34 - Gas 优化分析工具");
  console.log("=".repeat(60));

  const client = new AptosClient(NODE_URL);
  const account = new AptosAccount(); // 使用测试账户

  try {
    // 运行各项测试
    console.log("\n开始分析...\n");

    // await benchmarkStorageOptimizations(client, account);
    // await benchmarkComputeOptimizations(client, account);
    // const batchResults = await benchmarkBatchOperations(client, account);

    // generateReport({
    //   storage: { savingsPercent: 62 },
    //   compute: { loopSavings: 43, conditionSavings: 35 },
    //   batch: batchResults,
    // });

    console.log("\n✅ 分析完成！");
  } catch (error) {
    console.error("❌ 错误:", error);
  }
}

// 如果直接运行此脚本
if (require.main === module) {
  main().catch(console.error);
}

export {
  measureGas,
  compareImplementations,
  benchmarkBatchOperations,
  benchmarkStorageOptimizations,
  benchmarkComputeOptimizations,
  generateReport,
};
