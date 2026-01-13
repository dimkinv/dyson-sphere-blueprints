class Api::V1::BlueprintsController < ApplicationController
  include BlueprintsFilters

  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :set_cache_headers, only: [:index, :show]

  def index
    set_filters
    general_scope = policy_scope(Blueprint.light_query)
      .joins(:collection)
      .where(collection: { type: "Public" })

    last_modified = general_scope.maximum(:updated_at)

    if stale?(etag: [general_scope, current_user], last_modified: last_modified, public: true)
      blueprints = filter(general_scope.with_associations)
      blueprints = blueprints.page(params[:page])

      render json: {
        blueprints: blueprints.map { |blueprint| serialize_blueprint(blueprint) },
        pagination: {
          page: blueprints.current_page,
          total_pages: blueprints.total_pages,
          total_count: blueprints.total_count,
        },
      }
    end
  end

  def show
    blueprint = Blueprint.friendly.find(params[:id])
    authorize blueprint

    if stale?(etag: [blueprint, current_user], last_modified: blueprint.updated_at, public: true)
      render json: serialize_blueprint(blueprint, include_code: true)
    end
  end

  private

  def serialize_blueprint(blueprint, include_code: false)
    {
      id: blueprint.id,
      slug: blueprint.slug,
      title: blueprint.title,
      description: blueprint.description&.to_plain_text,
      type: blueprint.type,
      tags: blueprint.tags.map(&:name),
      author: {
        id: blueprint.user.id,
        username: blueprint.user.username,
      },
      collection: {
        id: blueprint.collection.id,
        name: blueprint.collection.name,
        type: blueprint.collection.type,
      },
      game_version: {
        id: blueprint.game_version.id,
        name: blueprint.game_version.name,
        version_string: blueprint.game_version_string,
      },
      usage_count: blueprint.usage_count,
      cached_votes_total: blueprint.cached_votes_total,
      created_at: blueprint.created_at,
      updated_at: blueprint.updated_at,
    }.tap do |payload|
      payload[:encoded_blueprint] = blueprint.encoded_blueprint if include_code
    end
  end
end
