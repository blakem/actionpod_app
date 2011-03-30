RailsAdmin.authenticate_with do
  redirect_to root_path unless admin_signed_in?
end
