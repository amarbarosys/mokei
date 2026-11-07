// c
fn f(x: i32) -> i32 {
    let r = if x > 1 && x < 9 { 1 } else { 2 };
    for i in 0..3 {
        println!("{}", i);
    }
    match r {
        1 => 10,
        _ => 20,
    }
}

fn g<'a>(s: &'a str) -> &'a str { s }
