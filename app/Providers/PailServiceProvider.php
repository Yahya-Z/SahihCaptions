<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Laravel\Pail\Pail;

class PailServiceProvider extends ServiceProvider
{
    /**
     * Register services.
     */
    public function register(): void
    {
        if (! $this->app->environment('local')) {
            return;
        }

        $this->app->singleton('pail', function ($app) {
            return new Pail($app);
        });
    }

    /**
     * Bootstrap services.
     */
    public function boot(): void
    {
        //
    }
}