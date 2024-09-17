(function() {
  "use strict";
  App.CheckTarget = {
    initialize: function() {
      $("[data-check-trigger]").on("click", function() {
        const target_name = $(this).data("check-trigger");
        const $target = $(`[data-check-target=${target_name}]`);
        $target.prop("checked", $(this).prop("checked"));
      });
    }
  };
}).call(this);
