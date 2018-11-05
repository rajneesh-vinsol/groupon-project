ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
  if html_tag !~ /^\<label/
    %(#{ html_tag }
      <span class="form-error">
        #{ instance.error_message.join(',') }
      </span>
    ).html_safe
  else
    html_tag
  end
end
