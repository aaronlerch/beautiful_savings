$('#q').typeahead({
  ajax: {
    url: '/autocomplete',
    displayField: 'name',
    method: 'get',
    triggerLength: 1
  }
});