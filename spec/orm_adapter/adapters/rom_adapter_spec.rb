require 'spec_helper'
require 'orm_adapter/example_app_shared'
require 'rom-repository'
require 'dry-monads'

if !defined?(ROM)
  puts "** require 'rom' and start mongod to run the specs in #{__FILE__}"
else
  module ROM
    ROM_MEMORY_CONTAINER = ROM.container(:sql, 'sqlite::memory') do |conf|
      conf.default.connection.create_table(:users) do
        primary_key :id
        column :name, String
        column :rating, String

      end

      conf.relation(:users) do
        schema(infer: true) do
          associations do
            has_many :notes, as: :owner
          end
        end
      end

      conf.default.connection.create_table(:notes) do
        primary_key :id
        column :name, String
        column :rating, String
        column :owner_id, Integer
      end

      conf.relation(:notes) do
        schema(infer: true) do
          associations do
            belongs_to :user, as: :owner
          end
        end
      end
    end

    module SharedCommands
      def call_relation
        self.send(root.options[:name])
      end

      def create!(params)
        create(params)
      end

      def destroy(id)
        result = call_relation.where(id: id).delete
        if result == 0
          nil
        else
          result
        end
      end

      def destroy_object(object)
        result = call_relation.where(id: object.id).delete
        if result == 0
          nil
        else
          result
        end
      end
      def find(id)
        call_relation.where(id: id).one
      end

      def destroy_all
        call_relation.delete
      end

      def get!(id)
        call_relation.where(id: id).limit(1).one
      end

      def find_first(order: nil, conditions: nil)
        relation_builder = call_relation
        maybe_condition = Dry::Monads::Maybe(conditions).fmap {|c|
          relation_builder = relation_builder.where(c)
        }
        maybe_order = Dry::Monads::Maybe(order).fmap {|order_conditions|
          relation_builder = relation_builder.order(*order_conditions.map{|ord| Sequel.send(ord[1], ord[0])})
        }
        relation_builder.limit(1).one
      end

      def find_all(conditions: nil, order: nil, offset: nil, limit: nil)
        relation_builder = call_relation

        maybe_condition = Dry::Monads::Maybe(conditions).fmap {|c|
          relation_builder = relation_builder.where(c)
        }
        maybe_order = Dry::Monads::Maybe(order).fmap {|order_conditions|
          relation_builder = relation_builder.order(*order_conditions.map{|ord| Sequel.send(ord[1], ord[0])})
        }
        maybe_offset= Dry::Monads::Maybe(offset).fmap {|c|
          relation_builder = relation_builder.offset(c)
        }
        maybe_limit = Dry::Monads::Maybe(limit).fmap {|c|
          relation_builder = relation_builder.limit(c)
        }
        relation_builder.to_a
      end
    end

    module SharedModelCommands
      class << self
        delegate  :where, to: :repo
      end

      def create!(params)
        self.new(repo.create!(params).to_h)
      end

      def get!(id)
        self.new(repo.get!(id).to_h)
      end

      def get(id)
        record  = repo.get!(id)
        record ? self.new(record.to_h) : nil
      end

      def find_first(query)
        record  = repo.find_first(query)
        record ? self.new(record.to_h) : nil
      end

      def find_all(query)
        repo.find_all(query).map {|r| self.new(r.to_h)}
      end

      def find(id)
        self.new(repo.find(id).to_h)
      end

      def destroy(param)
        if param.class == self
          repo.destroy_object(param)
        elsif param.class == Integer || param.class == String
          repo.destroy(param)
        end
      end
    end

    class NotesRepo < ROM::Repository[:notes]
      include SharedCommands
      commands :create, :delete
    end

    class UsersRepo < ROM::Repository[:users]
      relations :notes
      commands :create, :delete
      include SharedCommands
    end


    class User
      extend SharedModelCommands
      extend ::OrmAdapter::ToAdapter
      self::OrmAdapter = ::ROM::OrmAdapter

      attr_accessor :id, :name, :rating

      def initialize(id:, name:, rating:)
        @id, @name, @rating = id, name, rating
      end

      def to_key
        id
      end

      def self.repo
        @repo ||= UsersRepo.new(ROM_MEMORY_CONTAINER)
      end

      def ==(other)
        id == other.id
      end
    end

    class Note
      extend SharedModelCommands
      extend ::OrmAdapter::ToAdapter
      self::OrmAdapter = ::ROM::OrmAdapter

      def self.repo
        @repo ||= NotesRepo.new(ROM_MEMORY_CONTAINER)
      end

    end

    # here be the specs!
    describe ROM::OrmAdapter do

      before do
        UsersRepo.new(ROM_MEMORY_CONTAINER).destroy_all
        NotesRepo.new(ROM_MEMORY_CONTAINER).destroy_all
      end


      it_should_behave_like "example app with orm_adapter" do
        let(:user_class) { User }
        let(:note_class) { Note }
      end
    end
  end

end
