import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test project creation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Owner should be able to create project
            Tx.contractCall('funding-tracker', 'add-project', [
                types.ascii("Test Project"),
                types.ascii("A test project description"),
                types.uint(1000000)
            ], deployer.address),
            
            // Non-owner should not be able to create project
            Tx.contractCall('funding-tracker', 'add-project', [
                types.ascii("Invalid Project"),
                types.ascii("Should fail"),
                types.uint(1000)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        block.receipts[1].result.expectErr().expectUint(100); // err-owner-only
    }
});

Clarinet.test({
    name: "Test expenditure recording",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // First create a project
        let setup = chain.mineBlock([
            Tx.contractCall('funding-tracker', 'add-project', [
                types.ascii("Test Project"),
                types.ascii("A test project description"),
                types.uint(1000000)
            ], deployer.address)
        ]);
        
        let block = chain.mineBlock([
            // Record valid expenditure
            Tx.contractCall('funding-tracker', 'record-expenditure', [
                types.uint(1), // project-id
                types.uint(500000), // amount
                types.principal(wallet1.address), // recipient
                types.ascii("Test expenditure"),
                types.uint(20230615) // date
            ], deployer.address),
            
            // Try to exceed allocated amount
            Tx.contractCall('funding-tracker', 'record-expenditure', [
                types.uint(1),
                types.uint(600000),
                types.principal(wallet1.address),
                types.ascii("Should fail - exceeds allocation"),
                types.uint(20230615)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        block.receipts[1].result.expectErr().expectUint(102); // err-insufficient-funds
    }
});
