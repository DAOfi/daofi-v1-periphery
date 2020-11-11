let tokensMinted = 0
let poolBalance = 0
let slope = 1
let n = 1

function log() {
  console.log(`tokens minted: ${tokensMinted}, quote reserve: ${poolBalance}`)
}

function init(
  slopeN: number,
  slopeD: number,
  exp: number
) {
  tokensMinted = 0
  poolBalance = 0
  slope = slopeN / slopeD
  n = exp
}

function swapToBase(quoteIn: number) {
  let tokensOut = (((poolBalance + quoteIn) / (slope / (n + 1))) ** (1 / (n + 1))) - tokensMinted
  tokensMinted += tokensOut
  poolBalance += quoteIn
  console.log(`swapped ${quoteIn} quote for ${tokensOut} base`)
  log()
  return tokensOut
}

function swapToQuote(tokensIn: number) {
  let quoteOut = poolBalance - ((slope / (n + 1)) * ((tokensMinted - tokensIn) ** (n + 1)))
  tokensMinted -= tokensIn
  poolBalance -= quoteOut
  console.log(`swapped ${tokensIn} base for ${quoteOut} quote`)
  log()
  return quoteOut
}

console.log('slope 1 exp 1')
init(1, 1, 1)
swapToQuote(swapToBase(100))

console.log('slope 1 exp 2')
init(1, 1, 2)
swapToQuote(swapToBase(100))

console.log('slope 1/2 exp 1')
init(1, 2, 1)
swapToQuote(swapToBase(100))

console.log('slope 1/2 exp 2')
init(1, 2, 2)
swapToQuote(swapToBase(100))

console.log('slope 2 exp 1')
init(2, 1, 1)
swapToQuote(swapToBase(100))

console.log('slope 2 exp 2')
init(2, 1, 2)
swapToQuote(swapToBase(100))