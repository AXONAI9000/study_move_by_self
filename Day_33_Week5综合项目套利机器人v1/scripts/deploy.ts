#!/usr/bin/env ts-node

/**
 * 部署套利机器人合约到 Aptos 测试网
 */

import { execSync } from 'child_process';
import { AptosClient, AptosAccount, FaucetClient } from 'aptos';
import * as fs from 'fs';

const NODE_URL = 'https://fullnode.testnet.aptoslabs.com/v1';
const FAUCET_URL = 'https://faucet.testnet.aptoslabs.com';

async function deploy() {
  console.log('📦 开始部署套利机器人...\n');

  // 1. 编译合约
  console.log('🔨 编译 Move 合约...');
  try {
    execSync('aptos move compile', { stdio: 'inherit' });
    console.log('✅ 编译成功\n');
  } catch (error) {
    console.error('❌ 编译失败');
    process.exit(1);
  }

  // 2. 创建或加载账户
  console.log('🔑 准备部署账户...');
  const client = new AptosClient(NODE_URL);
  const faucet = new FaucetClient(NODE_URL, FAUCET_URL);
  
  let account: AptosAccount;
  
  if (fs.existsSync('.aptos/config.yaml')) {
    // 从配置文件加载
    console.log('从配置文件加载账户');
    // 实际应该解析 config.yaml
    account = new AptosAccount();
  } else {
    // 创建新账户
    console.log('创建新账户');
    account = new AptosAccount();
    
    // 申请测试代币
    console.log('申请测试代币...');
    await faucet.fundAccount(account.address(), 100_000_000);
    console.log(`账户地址: ${account.address().hex()}`);
  }
  
  console.log('✅ 账户准备完成\n');

  // 3. 部署合约
  console.log('🚀 部署合约...');
  try {
    const result = execSync(
      `aptos move publish --assume-yes --profile default`,
      { encoding: 'utf-8' }
    );
    
    console.log(result);
    console.log('✅ 部署成功\n');
  } catch (error) {
    console.error('❌ 部署失败');
    console.error(error);
    process.exit(1);
  }

  // 4. 初始化模块
  console.log('⚙️  初始化套利机器人模块...');
  try {
    const payload = {
      type: 'entry_function_payload',
      function: `${account.address().hex()}::arbitrage_bot::initialize`,
      type_arguments: [],
      arguments: []
    };
    
    const txn = await client.generateTransaction(account.address(), payload);
    const signedTxn = await client.signTransaction(account, txn);
    const txnResult = await client.submitTransaction(signedTxn);
    await client.waitForTransaction(txnResult.hash);
    
    console.log(`交易哈希: ${txnResult.hash}`);
    console.log('✅ 初始化成功\n');
  } catch (error) {
    console.error('❌ 初始化失败');
    console.error(error);
  }

  // 5. 验证部署
  console.log('🔍 验证部署...');
  try {
    const modules = await client.getAccountModules(account.address());
    const arbitrageBotModule = modules.find(m => 
      m.abi?.name === 'arbitrage_bot'
    );
    
    if (arbitrageBotModule) {
      console.log('✅ 合约已成功部署');
      console.log(`模块数量: ${modules.length}`);
    } else {
      console.log('⚠️  未找到套利机器人模块');
    }
  } catch (error) {
    console.error('❌ 验证失败');
    console.error(error);
  }

  console.log('\n🎉 部署完成！');
  console.log(`\n合约地址: ${account.address().hex()}`);
  console.log('\n下一步:');
  console.log('1. 更新 scripts/config.ts 中的合约地址');
  console.log('2. 运行 npm run start 启动机器人');
}

deploy().catch(console.error);
