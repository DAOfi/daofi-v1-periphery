let tokensMinted = 0
let poolBalance = 0
let slope = 1
let n = 1

function logCont() {
  console.log(`tokens minted: ${tokensMinted}, pool balance: ${poolBalance}`)
}

function initCont(
  slopeN: number,
  slopeD: number,
  exp: number
) {
  tokensMinted = 0
  poolBalance = 0
  slope = slopeN / slopeD
  n = exp
}

function buyTokens(poolIn: number) {
  let tokensOut = (((poolBalance + poolIn) / (slope / (n + 1))) ** (1 / (n + 1))) - tokensMinted
  tokensMinted += tokensOut
  poolBalance += poolIn
  console.log(`swapped ${poolIn} pool in for ${tokensOut} tokens`)
  logCont()
  return tokensOut
}

function sellTokens(tokensIn: number) {
  let poolOut = poolBalance - ((slope / (n + 1)) * ((tokensMinted - tokensIn) ** (n + 1)))
  tokensMinted -= tokensIn
  poolBalance -= poolOut
  console.log(`swapped ${tokensIn} tokens for ${poolOut} pool out`)
  logCont()
  return poolOut
}

console.log('cont slope 1 exp 1')
initCont(1, 1, 1)
sellTokens(buyTokens(100))

console.log('\ncont slope 1 exp 2')
initCont(1, 1, 2)
sellTokens(buyTokens(100))

console.log('\ncont slope 1/2 exp 1')
initCont(1, 2, 1)
sellTokens(buyTokens(100))

console.log('\ncont slope 1/2 exp 2')
initCont(1, 2, 2)
sellTokens(buyTokens(100))

console.log('\ncont slope 2 exp 1')
initCont(2, 1, 1)
sellTokens(buyTokens(100))

console.log('\ncont slope 2 exp 2')
initCont(2, 1, 2)
sellTokens(buyTokens(100))

// lets do similar calculations from a reserve pool
let baseReserve = 0
let quoteReserve = 0
let s = 0

function logRes() {
  console.log(`base reserve: ${baseReserve}, quote reserve: ${quoteReserve}. s: ${s}`)
}

function initRes(
  slopeN: number,
  slopeD: number,
  exp: number,
  baseR: number,
  quoteR: number,
) {
  baseReserve = baseR
  quoteReserve = quoteR
  slope = slopeN / slopeD
  n = exp
  s = (quoteReserve / (slope / (n + 1))) ** (1 / (n + 1))
}

function swapToBase(quoteIn: number) {
  let baseOut = (((quoteReserve + quoteIn) / (slope / (n + 1))) ** (1 / (n + 1))) - s
  s += baseOut
  quoteReserve += quoteIn
  baseReserve -= baseOut
  console.log(`swapped ${quoteIn} quote for ${baseOut} base`)
  logRes()
  return baseOut
}

function swapToQuote(baseIn: number) {
  let quoteOut = quoteReserve - ((slope / (n + 1)) * ((s - baseIn) ** (n + 1)))
  s -= baseIn
  baseReserve += baseIn
  quoteReserve -= quoteOut
  console.log(`swapped ${baseIn} base for ${quoteOut} quote`)
  logRes()
  return quoteOut
}

console.log('\nres slope 1 exp 1')
initRes(1, 1, 1, 1000, 1000)
swapToQuote(swapToBase(100))

console.log('\nres slope 1 exp 2')
initRes(1, 1, 2, 1000, 1000)
swapToQuote(swapToBase(100))

console.log('\nres slope 1/2 exp 1')
initRes(1, 2, 1, 1000, 1000)
swapToQuote(swapToBase(100))

console.log('\nres slope 1/2 exp 2')
initRes(1, 2, 2, 1000, 1000)
swapToQuote(swapToBase(100))

console.log('\nres slope 2 exp 1')
initRes(2, 1, 1, 1000, 1000)
swapToQuote(swapToBase(100))

console.log('\nres slope 2 exp 2')
initRes(2, 1, 2, 1000, 1000)
swapToQuote(swapToBase(100))