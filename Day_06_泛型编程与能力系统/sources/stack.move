module day06::stack{
    use std::vector;
    struct Stack<T> has drop{
        elements: vector<T>,
    }

    fun create_stack<T>(): Stack<T>{
        Stack{
            elements: vector::empty<T>(),
        }
    }

    fun push<T>(stack: &mut Stack<T>, value: T){
        vector::push_back(&mut stack.elements, value);
    }

    fun pop<T>(stack: &mut Stack<T>): T {   
        vector::pop_back(&mut stack.elements)
    }

    fun peek<T:copy>(stack: &Stack<T>) : T{
        stack.elements[vector::length(&stack.elements) - 1]
    }

    fun is_empty<T>(stack: &Stack<T>) : bool {
        vector::is_empty(&stack.elements)
    }

    fun size<T>(stack: &Stack<T>) : u64 {
        vector::length(&stack.elements)
    }

    #[test]
fun test_stack_operations() {
    let stack = create_stack<u64>();
    assert!(is_empty(&stack), 0);
    
    push(&mut stack, 10);
    push(&mut stack, 20);
    push(&mut stack, 30);
    
    assert!(size(&stack) == 3, 1);
    assert!(peek(&stack) == 30, 2);
    
    let val = pop(&mut stack);
    assert!(val == 30, 3);
    assert!(size(&stack) == 2, 4);
}
}
