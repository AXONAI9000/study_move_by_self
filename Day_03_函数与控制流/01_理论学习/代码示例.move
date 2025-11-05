/// Day 03 代码示例：函数与控制流
/// 本文件包含Move语言函数定义、控制流和常见模式的完整示例
module day03::control_flow {
    use std::debug;
    use std::vector;

    // ============================================
    // 第一部分：函数基础
    // ============================================

    /// 无参数、无返回值的函数
    public fun hello() {
        debug::print(&b"Hello, Move!");
    }

    /// 有参数、有返回值的函数
    public fun add(a: u64, b: u64): u64 {
        a + b  // 最后一个表达式作为返回值（无分号）
    }

    /// 多参数函数
    public fun sum_three(a: u64, b: u64, c: u64): u64 {
        a + b + c
    }

    /// 返回多个值（元组）
    public fun divide_with_remainder(a: u64, b: u64): (u64, u64) {
        let quotient = a / b;
        let remainder = a % b;
        (quotient, remainder)
    }

    /// 使用返回多值的函数
    public fun test_multiple_returns() {
        let (q, r) = divide_with_remainder(10, 3);
        debug::print(&q);  // 3
        debug::print(&r);  // 1
    }

    // ============================================
    // 第二部分：参数传递方式
    // ============================================

    /// 按值传递（Copy类型）
    public fun by_value(x: u64): u64 {
        x + 1  // x是副本
    }

    /// 不可变引用
    public fun by_immutable_ref(x: &u64): u64 {
        *x + 1  // 只能读取
    }

    /// 可变引用
    public fun by_mutable_ref(x: &mut u64) {
        *x = *x + 1;  // 可以修改
    }

    /// 引用传递示例
    public fun reference_example() {
        let a = 10;
        
        // 按值传递
        let b = by_value(a);
        debug::print(&a);  // 10（未改变）
        debug::print(&b);  // 11
        
        // 不可变引用
        let c = by_immutable_ref(&a);
        debug::print(&c);  // 11
        
        // 可变引用
        let mut d = 10;
        by_mutable_ref(&mut d);
        debug::print(&d);  // 11（已改变）
    }

    // ============================================
    // 第三部分：函数可见性
    // ============================================

    /// 私有函数（默认）：只能在模块内调用
    fun private_helper(): u64 {
        42
    }

    /// 公开函数：所有模块都可以调用
    public fun public_function(): u64 {
        private_helper()  // 可以调用私有函数
    }

    /// 入口函数：可以作为交易入口点
    public entry fun entry_function() {
        let _x = public_function();
    }

    // ============================================
    // 第四部分：if条件控制
    // ============================================

    /// 简单if-else表达式
    public fun max(a: u64, b: u64): u64 {
        if (a > b) {
            a
        } else {
            b
        }
    }

    /// if-else if-else链
    public fun grade(score: u64): u8 {
        if (score >= 90) {
            1  // A
        } else if (score >= 80) {
            2  // B
        } else if (score >= 70) {
            3  // C
        } else if (score >= 60) {
            4  // D
        } else {
            5  // F
        }
    }

    /// if表达式赋值
    public fun abs_diff(a: u64, b: u64): u64 {
        let diff = if (a > b) {
            a - b
        } else {
            b - a
        };
        diff
    }

    /// 嵌套if
    public fun sign_product(a: u64, b: u64): u8 {
        if (a == 0) {
            0
        } else if (b == 0) {
            0
        } else {
            if (a > 0 && b > 0) {
                1  // 正数
            } else {
                2  // 负数（在无符号整数中不会出现）
            }
        }
    }

    // ============================================
    // 第五部分：while循环
    // ============================================

    /// 基本while循环
    public fun sum_to_n(n: u64): u64 {
        let mut i = 0;
        let mut sum = 0;
        
        while (i <= n) {
            sum = sum + i;
            i = i + 1;
        };
        
        sum
    }

    /// 条件while循环
    public fun find_power_of_two(n: u64): u64 {
        let mut power = 1;
        
        while (power < n) {
            power = power * 2;
        };
        
        power
    }

    /// 计算阶乘
    public fun factorial(n: u64): u64 {
        let mut result = 1;
        let mut i = 1;
        
        while (i <= n) {
            result = result * i;
            i = i + 1;
        };
        
        result
    }

    /// 计算斐波那契数列第n项
    public fun fibonacci(n: u64): u64 {
        if (n <= 1) {
            return n
        };
        
        let mut prev = 0;
        let mut curr = 1;
        let mut i = 2;
        
        while (i <= n) {
            let next = prev + curr;
            prev = curr;
            curr = next;
            i = i + 1;
        };
        
        curr
    }

    // ============================================
    // 第六部分：loop无限循环
    // ============================================

    /// 使用loop和break
    public fun find_divisor(n: u64): u64 {
        let mut i = 2;
        
        loop {
            if (i * i > n) {
                break  // 没有找到因数
            };
            
            if (n % i == 0) {
                return i  // 找到因数，返回
            };
            
            i = i + 1;
        };
        
        n  // 是质数
    }

    /// 使用break退出循环
    public fun first_even(start: u64): u64 {
        let mut i = start;
        
        loop {
            if (i % 2 == 0) {
                break
            };
            i = i + 1;
        };
        
        i
    }

    // ============================================
    // 第七部分：break和continue
    // ============================================

    /// 使用continue跳过偶数
    public fun sum_odd_numbers(n: u64): u64 {
        let mut i = 0;
        let mut sum = 0;
        
        while (i < n) {
            i = i + 1;
            
            if (i % 2 == 0) {
                continue  // 跳过偶数
            };
            
            sum = sum + i;
        };
        
        sum
    }

    /// 只处理特定条件的元素
    public fun sum_divisible_by_three(start: u64, end: u64): u64 {
        let mut i = start;
        let mut sum = 0;
        
        while (i <= end) {
            if (i % 3 != 0) {
                i = i + 1;
                continue  // 不是3的倍数，跳过
            };
            
            sum = sum + i;
            i = i + 1;
        };
        
        sum
    }

    // ============================================
    // 第八部分：提前返回
    // ============================================

    /// 使用return提前退出
    public fun check_positive(x: u64): bool {
        if (x == 0) {
            return false
        };
        
        // 其他复杂检查...
        true
    }

    /// 多处return
    public fun categorize(x: u64): u8 {
        if (x == 0) return 0;
        if (x < 10) return 1;
        if (x < 100) return 2;
        if (x < 1000) return 3;
        4
    }

    /// 在循环中使用return
    public fun find_in_range(start: u64, end: u64, target: u64): bool {
        let mut i = start;
        
        while (i <= end) {
            if (i == target) {
                return true  // 找到立即返回
            };
            i = i + 1;
        };
        
        false  // 未找到
    }

    // ============================================
    // 第九部分：abort和assert
    // ============================================

    // 错误码常量
    const E_DIVISION_BY_ZERO: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_INVALID_AMOUNT: u64 = 3;
    const E_OVERFLOW: u64 = 4;

    /// 使用abort终止执行
    public fun divide(a: u64, b: u64): u64 {
        if (b == 0) {
            abort E_DIVISION_BY_ZERO
        };
        a / b
    }

    /// 使用assert!检查条件
    public fun withdraw(balance: u64, amount: u64): u64 {
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(balance >= amount, E_INSUFFICIENT_BALANCE);
        balance - amount
    }

    /// 多重检查
    public fun safe_multiply(a: u64, b: u64): u64 {
        // 检查溢出
        if (a == 0 || b == 0) {
            return 0
        };
        
        let max_u64 = 18446744073709551615u64;
        assert!(a <= max_u64 / b, E_OVERFLOW);
        
        a * b
    }

    // ============================================
    // 第十部分：嵌套循环
    // ============================================

    /// 二维遍历
    public fun create_multiplication_table(size: u64): vector<vector<u64>> {
        let mut table = vector::empty();
        let mut i = 1;
        
        while (i <= size) {
            let mut row = vector::empty();
            let mut j = 1;
            
            while (j <= size) {
                vector::push_back(&mut row, i * j);
                j = j + 1;
            };
            
            vector::push_back(&mut table, row);
            i = i + 1;
        };
        
        table
    }

    /// 查找矩阵中的元素
    public fun find_in_matrix(matrix: &vector<vector<u64>>, target: u64): bool {
        let rows = vector::length(matrix);
        let mut i = 0;
        
        while (i < rows) {
            let row = vector::borrow(matrix, i);
            let cols = vector::length(row);
            let mut j = 0;
            
            while (j < cols) {
                if (*vector::borrow(row, j) == target) {
                    return true
                };
                j = j + 1;
            };
            
            i = i + 1;
        };
        
        false
    }

    // ============================================
    // 第十一部分：常见算法模式
    // ============================================

    /// 模式1：累加器
    public fun sum_vector(vec: &vector<u64>): u64 {
        let len = vector::length(vec);
        let mut sum = 0;
        let mut i = 0;
        
        while (i < len) {
            sum = sum + *vector::borrow(vec, i);
            i = i + 1;
        };
        
        sum
    }

    /// 模式2：查找
    public fun find_max(vec: &vector<u64>): u64 {
        assert!(vector::length(vec) > 0, 100);
        
        let len = vector::length(vec);
        let mut max = *vector::borrow(vec, 0);
        let mut i = 1;
        
        while (i < len) {
            let value = *vector::borrow(vec, i);
            if (value > max) {
                max = value;
            };
            i = i + 1;
        };
        
        max
    }

    /// 模式3：转换
    public fun double_all(vec: &vector<u64>): vector<u64> {
        let len = vector::length(vec);
        let mut result = vector::empty();
        let mut i = 0;
        
        while (i < len) {
            let value = *vector::borrow(vec, i);
            vector::push_back(&mut result, value * 2);
            i = i + 1;
        };
        
        result
    }

    /// 模式4：过滤
    public fun filter_even(vec: &vector<u64>): vector<u64> {
        let len = vector::length(vec);
        let mut result = vector::empty();
        let mut i = 0;
        
        while (i < len) {
            let value = *vector::borrow(vec, i);
            if (value % 2 == 0) {
                vector::push_back(&mut result, value);
            };
            i = i + 1;
        };
        
        result
    }

    /// 模式5：判断（所有元素满足条件）
    public fun all_positive(vec: &vector<u64>): bool {
        let len = vector::length(vec);
        let mut i = 0;
        
        while (i < len) {
            if (*vector::borrow(vec, i) == 0) {
                return false
            };
            i = i + 1;
        };
        
        true
    }

    /// 模式6：判断（任一元素满足条件）
    public fun any_greater_than_ten(vec: &vector<u64>): bool {
        let len = vector::length(vec);
        let mut i = 0;
        
        while (i < len) {
            if (*vector::borrow(vec, i) > 10) {
                return true
            };
            i = i + 1;
        };
        
        false
    }

    // ============================================
    // 第十二部分：表达式vs语句
    // ============================================

    /// 块表达式
    public fun block_expression(): u64 {
        let x = {
            let a = 10;
            let b = 20;
            a + b  // 无分号，这是表达式
        };  // x = 30
        
        let y = {
            let a = 5;
            a + 1;  // 有分号，这是语句
            100     // 块的值是最后一个表达式
        };  // y = 100
        
        x + y
    }

    /// if表达式
    public fun if_expression(x: u64): u64 {
        // if作为表达式
        let result = if (x > 10) {
            x * 2
        } else {
            x
        };
        
        result
    }

    // ============================================
    // 第十三部分：作用域和遮蔽
    // ============================================

    /// 变量遮蔽
    public fun shadowing_example(): u64 {
        let x = 10;
        debug::print(&x);  // 10
        
        let x = x + 1;  // 遮蔽之前的x
        debug::print(&x);  // 11
        
        let x = x * 2;  // 再次遮蔽
        debug::print(&x);  // 22
        
        x
    }

    /// 块作用域
    public fun scope_example(): u64 {
        let x = 10;
        
        {
            let x = 20;  // 内部作用域
            debug::print(&x);  // 20
        };
        
        debug::print(&x);  // 10
        x
    }

    // ============================================
    // 测试函数
    // ============================================

    #[test]
    fun test_add() {
        assert!(add(2, 3) == 5, 0);
    }

    #[test]
    fun test_max() {
        assert!(max(10, 20) == 20, 0);
        assert!(max(30, 15) == 30, 0);
    }

    #[test]
    fun test_sum_to_n() {
        assert!(sum_to_n(10) == 55, 0);  // 0+1+2+...+10
    }

    #[test]
    fun test_factorial() {
        assert!(factorial(5) == 120, 0);  // 5! = 120
    }

    #[test]
    fun test_fibonacci() {
        assert!(fibonacci(0) == 0, 0);
        assert!(fibonacci(1) == 1, 0);
        assert!(fibonacci(10) == 55, 0);
    }

    #[test]
    fun test_sum_odd_numbers() {
        assert!(sum_odd_numbers(10) == 25, 0);  // 1+3+5+7+9
    }

    #[test]
    #[expected_failure(abort_code = E_DIVISION_BY_ZERO)]
    fun test_divide_by_zero() {
        divide(10, 0);
    }

    #[test]
    #[expected_failure(abort_code = E_INSUFFICIENT_BALANCE)]
    fun test_insufficient_balance() {
        withdraw(100, 200);
    }
}
