// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
$(function() {
	
	// Links in new Tabs or Windows
	$('.bookmark h1 a').click(function() {
		window.open($(this).attr('href'), '_blank');
		return false;
	});
	
	/*
	// Buggy
	// Easy large links - clicky
	$('.bookmark').click(function() {
		window.open($(this).children('.the_link').children('a').attr('href'));
	});
	// Easy large links - mouse hover indicator
	$('.bookmark').hover(function() {
		$(this).css('cursor', 'pointer');
	});
	*/
	// Easy large links - background hover effect
	$('.bookmark').hover(
		function() {
			$(this).addClass('bookmark_hover');
		},
		function() {
			$(this).removeClass('bookmark_hover');
		}
	);
	
	$('#notice').css('opacity', 1);
	$('#notice').fadeTo(1500, 0.9).fadeTo(500, 0.33).slideUp();
	
})