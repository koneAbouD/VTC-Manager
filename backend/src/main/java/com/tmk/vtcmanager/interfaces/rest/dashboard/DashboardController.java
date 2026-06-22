package com.tmk.vtcmanager.interfaces.rest.dashboard;

import com.tmk.vtcmanager.application.usecases.dashboard.GetDashboardSummaryUseCase;
import com.tmk.vtcmanager.interfaces.rest.dashboard.dto.DashboardSummaryResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final GetDashboardSummaryUseCase getDashboardSummaryUseCase;

    @GetMapping("/summary")
    public DashboardSummaryResponse summary() {
        return getDashboardSummaryUseCase.execute();
    }
}
