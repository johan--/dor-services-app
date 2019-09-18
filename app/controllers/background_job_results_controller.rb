# frozen_string_literal: true

# Controller for background job results
class BackgroundJobResultsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: {
      errors: [
        { title: 'not found', detail: exception.message }
      ]
    }, status: :not_found
  end

  def show
    result = BackgroundJobResult.find(params[:id])
    @output = result.output
    @status = result.status

    render status: result.code
  end
end
