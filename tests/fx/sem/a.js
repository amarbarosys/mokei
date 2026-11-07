// c
function f(a, b) {
  if (a && b) {
    for (let i = 0; i < 3; i++) {
      b += i;
    }
  } else {
    a = a ? 1 : 2;
  }
  return a ?? b;
}
const g = (x) => x > 1 ? x : 0;
const s = "if (x) { while }";
