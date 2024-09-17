(function() {
  "use strict";
  App.Tags = {
    initialize: function() {

      var $selected_tags = $(".js-add-tags-selected").text();

      // Category
      var $tag_input;
      $tag_input = $("input.js-tag-list-category");

      $("body .js-add-tag-link-category").each(function() {

        var name = $(this).text();
        if($selected_tags.indexOf(name) >= 0) {
          $(this).toggleClass("is-active");
        }

        if ($(this).data("initialized") !== "yes") {
          $(this).on("click", function() {
            var current_tags;
            current_tags = $tag_input.val().split(",").filter(Boolean).map(function(x){ return x.trim() });
            if (current_tags.indexOf(name) >= 0) {
              current_tags.splice(current_tags.indexOf(name), 1);
            } else {
              current_tags.push(name);
            }
            $tag_input.val(current_tags.join(","));
            return false;
          }).data("initialized", "yes");
        }
      });

      // Subprefectures
      var $tag_input_subprefecture;
      $tag_input_subprefecture = $("input.js-tag-list-subprefecture");
      $("body .js-add-tag-link-subprefecture").each(function() {

        var name = $(this).text();
        if($selected_tags.indexOf(name) >= 0) {
          $(this).toggleClass("is-active");
        }

        if ($(this).data("initialized") !== "yes") {
          $(this).on("click", function() {
            var current_tags;
            current_tags = $tag_input_subprefecture.val().split(",").filter(Boolean).map(function(x){ return x.trim() });
            if (current_tags.indexOf(name) >= 0) {
              current_tags.splice(current_tags.indexOf(name), 1);
            } else {
              current_tags.push(name);
            }
            $tag_input_subprefecture.val(current_tags.join(","));
            return false;
          }).data("initialized", "yes");
        }
      });

      // Districts
      var $tag_input_distric;
      $tag_input_distric = $("input.js-tag-list-district");
      $("body .js-add-tag-link-district").each(function() {

        var name = $(this).text();
        if($selected_tags.indexOf(name) >= 0) {
          $(this).toggleClass("is-active");
        }

        if ($(this).data("initialized") !== "yes") {
          $(this).on("click", function() {
            var current_tags;
            current_tags = $tag_input_distric.val().split(",").filter(Boolean).map(function(x){ return x.trim() });
            if (current_tags.indexOf(name) >= 0) {
              current_tags.splice(current_tags.indexOf(name), 1);
            } else {
              current_tags.push(name);
            }
            $tag_input_distric.val(current_tags.join(","));
            return false;
          }).data("initialized", "yes");
        }
      });

      $("body .js-add-tag-link-category").on("click", function() {
        $(this).toggleClass("is-active");
      });

      $("body .js-add-tag-link-subprefecture").on("click", function() {
        $(this).toggleClass("is-active");
      });

      $("body .js-add-tag-link-district").on("click", function() {
        $(this).toggleClass("is-active");
      });

    }
  };
}).call(this);
