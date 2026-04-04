package com.feedingsystem.tmr.data

import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Path

interface TmrApi {
    @GET("v1/farm/profile")
    suspend fun getFarmProfile(): FarmProfileDto

    @PUT("v1/farm/profile")
    suspend fun updateFarmProfile(@Body request: FarmProfileUpdateRequest): FarmProfileDto

    @GET("v1/formulas")
    suspend fun listFormulas(): List<FormulaDto>

    @GET("v1/formulas/{formulaId}")
    suspend fun getFormula(@Path("formulaId") formulaId: String): FormulaDto

    @PUT("v1/formulas/{formulaId}")
    suspend fun updateFormula(
        @Path("formulaId") formulaId: String,
        @Body request: SaveFormulaRequest
    ): FormulaDto

    @GET("v1/formulas/{formulaId}/stage-comparison")
    suspend fun getStageComparison(@Path("formulaId") formulaId: String): StageComparisonResponseDto

    @POST("v1/analysis-runs")
    suspend fun createAnalysisRun(@Body request: CreateAnalysisRunRequest): AnalysisWorkflowResponseDto

    @GET("v1/analysis-runs/{runId}")
    suspend fun getAnalysisRun(@Path("runId") runId: String): AnalysisWorkflowResponseDto
}

object TmrApiClient {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = HttpLoggingInterceptor.Level.BASIC
    }

    /**
     * Android Emulator에서 호스트 PC의 localhost는 10.0.2.2로 접근해야 한다.
     * NestJS API가 `npm run dev`로 4000번 포트에서 떠 있다는 전제다.
     */
    val api: TmrApi by lazy {
        val client = OkHttpClient.Builder()
            .addInterceptor(loggingInterceptor)
            .build()

        Retrofit.Builder()
            .baseUrl("http://10.0.2.2:4000/")
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(TmrApi::class.java)
    }
}