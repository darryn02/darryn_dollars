// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "jquery"
import "jquery_ujs"
import "popper"
import "bootstrap"

$(document).on("input", ".bet-form .js-wager-amount-bet", function() {
    const $this = $(this);
    const odds = 100.0 / parseFloat($this.data("odds"));
    const amountBet = parseFloat($this.val().replace("$", ""));
    if(!isNaN(amountBet)) {
      var toWin = odds < 0 ? amountBet * (-1) * odds : amountBet / odds;
      var otherInput = $this.closest(".bet-form").find("input.js-wager-to-win").first();
      otherInput.val(roundToTwo(toWin));
      formatCurrency(otherInput, "blur");
    }
});

$(document).on("input", ".bet-form .js-wager-to-win", function() {
    const $this = $(this);
    const odds = 100.0 / parseFloat($this.data("odds"));
    const toWin = parseFloat($this.val().replace("$", ""));

    if(!isNaN(toWin)) {
      var amountBet = odds < 0 ? (-1) * toWin / odds : toWin * odds;
      var otherInput = $this.closest(".bet-form").find("input.js-wager-amount-bet").first();
      otherInput.val(roundToTwo(amountBet));
      formatCurrency(otherInput, "blur");
    }
});

function roundToTwo(num) {
  return +(Math.round(num + "e+2")  + "e-2");
}

$(document).on("keyup", "input[data-type='currency']", function() {
  formatCurrency($(this));
});

$(document).on("blur", "input[data-type='currency']", function() {
  formatCurrency($(this), "blur");
});

//
// Quick amount chips in the bet form
//

$(document).on("click", ".js-quick-amount", function(event) {
  event.preventDefault();
  const $chip = $(this);
  const $input = $chip.closest(".bet-form").find("input.js-wager-amount-bet").first();
  $input.val($chip.data("amount")).trigger("input");
  formatCurrency($input, "blur");
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

const FLASH_ICONS = {
  success: "check-circle-fill",
  error: "exclamation-triangle-fill"
};

function renderFlash(kind, message, asHtml) {
  const $flash = $(".flash-from-js")
    .removeClass("dd-flash--success dd-flash--error")
    .addClass("fade-in-down-out dd-flash--" + kind)
    .empty();

  const $icon = $(
    '<svg class="dd-icon" aria-hidden="true" focusable="false">' +
    '<use href="#i-' + FLASH_ICONS[kind] + '"></use></svg>'
  );
  const $body = $("<div></div>");

  if (asHtml) {
    $body.html(message);
  } else {
    $body.text(message);
  }

  $flash.append($icon).append($body);
  setTimeout(cleanUp, 5000);
}

function showSuccessFlash(message) {
  renderFlash("success", message, false);
}

function showErrorFlash(pMessage, pOptions) {
  const options = pOptions || { html: false };
  renderFlash("error", pMessage, options.html);
}

function cleanUp() {
  $(".flash-from-js")
    .removeClass("fade-in-down-out dd-flash--success dd-flash--error")
    .empty();
}

window.showSuccessFlash = showSuccessFlash;
window.showErrorFlash = showErrorFlash;

//
// Spinner overlay
//


// Second half lines are re-scraped on demand, so this navigation can block for
// several seconds. The overlay used to be bound to a selector no view rendered.
$(document).on("click", "a.js-slow-nav", function() {
  $(".dd-loading").addClass("is-visible");
});
