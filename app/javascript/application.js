// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "jquery"
import "jquery_ujs"
import "popper"
import "bootstrap"

$(function() {
  $(".bet-form .js-wager-amount-bet").on("input", function() {
    const $this = $(this);
    const odds = 100.0 / parseFloat($this.data("odds"));
    const amountBet = parseFloat($this.val().replace("$", ""));
    if(!isNaN(amountBet)) {
      var toWin = odds < 0 ? amountBet * (-1) * odds : amountBet / odds;
      var otherInput = $this.closest(".row").find("input.js-wager-to-win").first();
      otherInput.val(roundToTwo(toWin));
      formatCurrency(otherInput, "blur");
    }
  });

  $(".bet-form .js-wager-to-win").on("input", function() {
    const $this = $(this);
    const odds = 100.0 / parseFloat($this.data("odds"));
    const toWin = parseFloat($this.val().replace("$", ""));

    if(!isNaN(toWin)) {
      var amountBet = odds < 0 ? (-1) * toWin / odds : toWin * odds;
      var otherInput = $this.closest(".row").find("input.js-wager-amount-bet").first();
      otherInput.val(roundToTwo(amountBet));
      formatCurrency(otherInput, "blur");
    }
  });
});

function roundToTwo(num) {
  return +(Math.round(num + "e+2")  + "e-2");
}

$("input[data-type='currency']").on({
  keyup: function() {
    formatCurrency($(this));
  },
  blur: function() {
    formatCurrency($(this), "blur");
  }
});


function formatNumber(n) {
// format number 1000000 to 1,234,567

return n.replace(/[^\d\-]/g, "").replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}


function formatCurrency(input, blur) {
  // appends $ to value, validates decimal side
  // and puts cursor back in right position.

  var hasFocus = input.is(":focus");

  // get input value
  var input_val = input.val();

  // don't validate empty input
  if (input_val === "") { return; }

  // original length
  var original_len = input_val.length;

  // initial caret position
  var caret_pos = input.prop("selectionStart");

  // check for decimal
  if (input_val.indexOf(".") >= 0) {

    // get position of first decimal
    // this prevents multiple decimals from
    // being entered
    var decimal_pos = input_val.indexOf(".");

    // split number by decimal point
    var left_side = input_val.substring(0, decimal_pos);
    var right_side = input_val.substring(decimal_pos);

    // add commas to left side of number
    left_side = formatNumber(left_side);

    // validate right side
    right_side = formatNumber(right_side);

    // On blur make sure 2 numbers after decimal
    if (blur === "blur") {
      right_side += "00";
    }

    // Limit decimal to only 2 digits
    right_side = right_side.substring(0, 2);

    // join number by .
    input_val = "$" + left_side + "." + right_side;

  } else {
    // no decimal entered
    // add commas to number
    // remove all non-digits
    input_val = formatNumber(input_val);
    input_val = "$" + input_val;

    // final formatting
    if (blur === "blur") {
      input_val += ".00";
    }
  }

  // send updated string to input
  input.val(input_val);

  if(hasFocus) {
    // put caret back in the right position
    var updated_len = input_val.length;
    caret_pos = updated_len - original_len + caret_pos;
    input[0].setSelectionRange(caret_pos, caret_pos);
  }
}


//
// Flash stuff
//

function showSuccessFlash(message) {
  $(".flash-from-js").addClass("fade-in-down-out flash-success").text(message);
  setTimeout(cleanUp, 5000);
}

function showErrorFlash(pMessage, pOptions) {
  const options = pOptions || { html: false };
  const $flashSelector = $(".flash-from-js").addClass("fade-in-down-out flash-error");

  if (options.html) {
    $flashSelector.html(pMessage);
  } else {
    $flashSelector.text(pMessage);
  }

  setTimeout(cleanUp, 5000);
}

function cleanUp() {
  $(".flash-from-js").removeClass("fade-in-down-out flash-success flash-error").text("");
}

window.showSuccessFlash = showSuccessFlash;
window.showErrorFlash = showErrorFlash;

//
// Spinner overlay
//


$("a.second-half-lines").on("click", function() {
  $("div.spanner").addClass("show");
  $("div.overlay").addClass("show");
});
